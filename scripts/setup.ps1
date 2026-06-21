#Requires -Version 5.1
<#
.SYNOPSIS
  doit-skill PowerShell installer for Windows (native, no WSL required)

.DESCRIPTION
  Installs doit-skill and all dependencies on Windows using native PowerShell.
  Uses winget/choco for package management, native PS cmdlets for file ops.

.PARAMETER Agent
    Target AI coding CLI: claude, opencode, codex, oh-my-pi, mimo, jcode, auto (default)

.PARAMETER SkipOptional
    Skip optional skills and external tools

.PARAMETER SkipUpdates
    Skip updating already-installed tools

.PARAMETER SkipInits
    Skip tool initialization (rtk init, lean-ctx onboard, etc.)

.PARAMETER Global
    Install to global skill directory instead of project-local

.PARAMETER DryRun
    Show what would be installed without making changes

.EXAMPLE
  .\scripts\setup.ps1
  .\scripts\setup.ps1 -Agent claude -SkipOptional
  .\scripts\setup.ps1 -Agent auto -Global -SkipUpdates

.NOTES
  Equivalent to scripts/setup.sh but for native Windows PowerShell.
  All bash-specific tools (grep, rsync, md5sum, etc.) replaced with PS cmdlets.
#>

[CmdletBinding()]
param(
  [ValidateSet("claude", "opencode", "codex", "oh-my-pi", "mimo", "jcode", "auto")]
  [string]$Agent = "auto",

  [switch]$SkipOptional,
  [switch]$SkipUpdates,
  [switch]$SkipInits,
  [switch]$Global,
  [switch]$DryRun
)

# ============================================================================
# Helpers
# ============================================================================

# Progress spinner - runs a script block with animated progress
function Start-Spin {
  [CmdletBinding()]
  param(
    [int]$TimeoutSeconds = 120,
    [string]$Label,
    [scriptblock]$Command,
    [switch]$UsePty
  )

  Write-Host "[$('⏳')] $Label..." -ForegroundColor Blue
  Write-Host "     > $($Command.ToString().Substring(0, [Math]::Min(120, $Command.ToString().Length)))"
  Write-Host ""

  $frames = @("⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏")
  $frameIndex = 0
  $sw = [System.Diagnostics.Stopwatch]::StartNew()

  # Background spinner
  $job = Start-Job -ScriptBlock {
    param($frames)
    $idx = 0
    while ($true) {
      Write-Host -NoNewline "`r $([char]0x1b)[2K$($frames[$idx]) running..." -ForegroundColor DarkGray
      $idx = ($idx + 1) % $frames.Length
      Start-Sleep -Milliseconds 500
    }
  } -ArgumentList $frames

  $exitCode = 0
  try {
    # Run the command with timeout
    $processJob = Start-Job -ScriptBlock $Command
    $completed = Wait-Job $processJob -TimeoutSec $TimeoutSeconds
    if ($completed) {
      $output = Receive-Job $processJob
      if ($output) { Write-Host $output }
      $exitCode = $((Get-Job $processJob).State)
    } else {
      # Timeout - stop the job
      Stop-Job $processJob
      $exitCode = 124
    }
  } catch {
    $exitCode = $_.Exception.HResult
  } finally {
    Stop-Job $job
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    Remove-Job $processJob -Force -ErrorAction SilentlyContinue
    Write-Host "`r$([char]0x1b)[2K" -NoNewline  # Clear spinner line
  }

  $elapsed = $sw.Elapsed
  $timeStr = if ($elapsed.TotalMinutes -ge 1) {
    "{0}m {1}s" -f [int]$elapsed.TotalMinutes, [int]($elapsed.Seconds % 60)
  } else {
    "{0}s" -f [int]$elapsed.TotalSeconds
  }

  if ($exitCode -eq 0) {
    Write-Host "[✓] $Label completed ($timeStr)" -ForegroundColor Green
  } elseif ($exitCode -eq 124) {
    Write-Host "[!] $Label timed out after ${TimeoutSeconds}s (ran $timeStr)" -ForegroundColor Yellow
  } else {
    Write-Host "[!] $Label failed (exit $exitCode, $timeStr)" -ForegroundColor Yellow
  }

  return $exitCode
}

# Check if a command exists (cross-platform equivalent of `command -v`)
function Test-Command([string]$Name) {
  return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

# File hash (equivalent of md5sum)
function Get-FileHashPortable {
  param([string]$Path)
  $hash = Get-FileHash -Path $Path -Algorithm MD5 -ErrorAction SilentlyContinue
  return $hash.Hash
}

# Create temp directory
function New-TempDir {
  return [System.IO.Path]::GetTempFileName() | ForEach-Object {
    Remove-Item $_
    New-Item -ItemType Directory -Path "$_"
  }
}

# Create temp file
function New-TempFile {
  return [System.IO.Path]::GetTempFileName()
}

# Read YAML value (simple parser for our config format)
function Get-YamlValue {
  param([string]$Path, [string]$Key)
  if (-not (Test-Path $Path)) { return $null }
  $content = Get-Content $Path -Raw
  if ($content -match "(?m)^\s*$Key:\s*(.+)$") {
    return $Matches[1].Trim()
  }
  return $null
}

# ============================================================================
# Colors (using ANSI codes that work in modern Windows terminals)
# ============================================================================
$script:RED = "`e[0;31m"
$script:GREEN = "`e[0;32m"
$script:YELLOW = "`e[1;33m"
$script:BLUE = "`e[0;34m"
$script:CYAN = "`e[0;36m"
$script:NC = "`e[0m"

function Write-Info    { Write-Host "${BLUE}[INFO]${NC} $args" }
function Write-Success { Write-Host "${GREEN}[✓]${NC} $args" }
function Write-Skip    { Write-Host "${CYAN}[~]${NC} $args" }
function Write-Warn    { Write-Host "${YELLOW}[!]${NC} $args" }
function Write-Error   { Write-Host "${RED}[✗]${NC} $args" }

# ============================================================================
# Platform detection
# ============================================================================
$script:Platform = "windows"
$script:IsAdmin = ([Security.Principal.WindowsPrincipal] `
  [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole( `
  [Security.Principal.WindowsBuiltInRole]::Administrator)

# Detect package manager
function Get-PackageManager {
  if (Test-Command "winget") { return "winget" }
  if (Test-Command "choco")  { return "choco" }
  if (Test-Command "scoop")  { return "scoop" }
  return $null
}

$script:PkgMgr = Get-PackageManager

# ============================================================================
# Agent detection
# ============================================================================
function Get-DetectedAgent {
  param([string]$Agent)

  if ($Agent -ne "auto") { return $Agent }

  # Check for running agents in PATH
  $agents = @("claude", "opencode", "codex", "jcode", "mimo")
  foreach ($name in $agents) {
    if (Test-Command $name) { return $name }
  }

  return "claude"  # Default
}

$script:AgentType = Get-DetectedAgent $Agent

# ============================================================================
# Agent-specific paths
# ============================================================================
function Get-AgentPaths {
  param([string]$Agent)

  switch ($Agent) {
    "claude" {
      return @{
        SkillDir          = ".claude/skills"
        GlobalSkillDir    = "$HOME/.claude/skills"
        MainInstructions  = "CLAUDE.md"
        McpConfigFile     = "$HOME/.claude.json"
      }
    }
    "opencode" {
      return @{
        SkillDir          = ".opencode/skills"
        GlobalSkillDir    = "$HOME/.config/opencode/skills"
        MainInstructions  = "AGENTS.md"
        McpConfigFile     = "$HOME/.config/opencode/opencode.json"
      }
    }
    "codex" {
      return @{
        SkillDir          = ".agents/skills"
        GlobalSkillDir    = "$HOME/.codex/skills"
        MainInstructions  = "AGENTS.md"
        McpConfigFile     = "$HOME/.codex/config.toml"
      }
    }
    "oh-my-pi" {
      return @{
        SkillDir          = ".omp/skills"
        GlobalSkillDir    = "$HOME/.config/omp/skills"
        MainInstructions  = "AGENTS.md"
        McpConfigFile     = "$HOME/.config/omp/mcp.json"
      }
    }
    "mimo" {
      return @{
        SkillDir          = ".mimo/skills"
        GlobalSkillDir    = "$HOME/.config/mimo/skills"
        MainInstructions  = "AGENTS.md"
        McpConfigFile     = "$HOME/.config/mimo/settings.json"
      }
    }
    "jcode" {
      return @{
        SkillDir          = ".jcode/skills"
        GlobalSkillDir    = "$HOME/.jcode/skills"
        MainInstructions  = "AGENTS.md"
        McpConfigFile     = "$HOME/.jcode/mcp.json"
      }
    }
    default {
      return @{
        SkillDir          = ".ai/skills"
        GlobalSkillDir    = "$HOME/.ai/skills"
        MainInstructions  = "AGENTS.md"
        McpConfigFile     = "$HOME/.ai/mcp.json"
      }
    }
  }
}

$script:Paths = Get-AgentPaths $script:AgentType
$script:SkillDir        = $script:Paths.SkillDir
$script:GlobalSkillDir  = $script:Paths.GlobalSkillDir
$script:MainInstructions = $script:Paths.MainInstructions
$script:McpConfigFile   = $script:Paths.McpConfigFile

$script:GH_PROXY = "https://v6.gh-proxy.org"
$script:REPO_URL = "${script:GH_PROXY}/https://github.com/1JayPeng/doit-skill"
$script:UpdatedFiles = @()
$script:InstallCache = "$HOME/.doit/install-cache.json"

# If -Global, use global skill directory
if ($Global) {
  $script:SkillDir = $script:GlobalSkillDir
}

# ============================================================================
# Header
# ============================================================================
Write-Host "=========================================="
Write-Host "  doit-skill Installer (PowerShell)"
Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "  Agent: $($script:AgentType)"
Write-Host "  Platform: $([System.Environment]::OSVersion.VersionString)"
Write-Host "  PowerShell: $($PSVersionTable.PSVersion.ToString())"
Write-Host "  Package Manager: $($script:PkgMgr)"
Write-Host "=========================================="
Write-Host ""

# ============================================================================
# Interactive config prompts
# ============================================================================
function Read-YesNo {
  param(
    [string]$Prompt,
    [bool]$DefaultYes = $true
  )

  $suffix = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }
  $answer = Read-Host "$Prompt $suffix"

  if ([string]::IsNullOrWhiteSpace($answer)) {
    return $DefaultYes
  }

  return ($answer -match "^[yY](es)?$")
}

$script:DocCapture = Read-YesNo -Prompt "Enable doc-capture (persist reference docs in .doit/docs/)" -DefaultYes $true
$script:SubagentEnabled = Read-YesNo -Prompt "Enable subagent orchestration (parallel, token-intensive)" -DefaultYes $true
$script:AutoCommit = Read-YesNo -Prompt "Enable auto commit (skip confirmation before commit/push)" -DefaultYes $false
$script:HeadroomProxy = Read-YesNo -Prompt "Enable headroom proxy (auto-compress all tool output, 60-95% token savings)" -DefaultYes $true

Write-Host ""
Write-Host "  [CONFIG] doc-capture: $($script:DocCapture) | subagent: $($script:SubagentEnabled) | auto-commit: $($script:AutoCommit) | headroom-proxy: $($script:HeadroomProxy)"

# ============================================================================
# Write ~/.doit/config.yaml
# ============================================================================
$DoitDir = Join-Path $HOME ".doit"
if (-not (Test-Path $DoitDir)) {
  New-Item -ItemType Directory -Path $DoitDir -Force | Out-Null
}

$ConfigPath = Join-Path $DoitDir "config.yaml"
if (-not (Test-Path $ConfigPath)) {
  $yaml = @"
subagent:
  enabled: $($script:SubagentEnabled.ToString().ToLower())
auto_commit:
  enabled: $($script:AutoCommit.ToString().ToLower())
doc-capture:
  enabled: $($script:DocCapture.ToString().ToLower())
headroom:
  proxy:
    enabled: $($script:HeadroomProxy.ToString().ToLower())
    port: 8787
commit:
  branch: branch
"@
  $yaml | Set-Content -Path $ConfigPath -Encoding UTF8
  Write-Success "Created $ConfigPath"
} else {
  Write-Success "$ConfigPath already exists (keeping current settings)"
}

# ============================================================================
# Read config values
# ============================================================================
function Get-ConfigValue {
  param([string]$Key)
  $val = Get-YamlValue -Path $ConfigPath -Key $Key
  if ($val -match '^\w+$') { return $val }
  # Nested key lookup
  $content = Get-Content $ConfigPath -Raw
  if ($content -match "(?m)$Key:\s*(.+?)\s*$") { return $Matches[1].Trim() }
  return $null
}

# ============================================================================
# Tavily API Key
# ============================================================================
$script:TavilyApiKey = $env:TAVILY_API_KEY
$script:TavilyConfigured = $false

if (-not [string]::IsNullOrWhiteSpace($script:TavilyApiKey)) {
  $script:TavilyConfigured = $true
  Write-Success "Tavily API key found in environment"
} elseif (Test-Path ".env") {
  $envContent = Get-Content ".env" -Raw
  if ($envContent -match 'TAVILY_API_KEY[=:]\s*["'']?([^"'`\r\n]+)') {
    $script:TavilyApiKey = $Matches[1].Trim()
    $script:TavilyConfigured = $true
    Write-Success "Tavily API key found in .env"
  }
}

# Check existing MCP configs
$mcpConfigs = @(
  "$HOME/.claude.json",
  "$HOME/.config/opencode/opencode.json",
  "$HOME/.codex/config.toml"
)

foreach ($cfg in $mcpConfigs) {
  if (Test-Path $cfg) {
    $content = Get-Content $cfg -Raw
    if ($content -match 'tavily') {
      $script:TavilyConfigured = $true
      Write-Success "Tavily already configured in $cfg"
      break
    }
  }
}

# Prompt for Tavily API key if not configured
if (-not $script:TavilyConfigured) {
  Write-Host ""
  $key = Read-Host "Tavily API Key (for web search, or press Enter to skip)"
  if (-not [string]::IsNullOrWhiteSpace($key)) {
    $script:TavilyApiKey = $key
  }
}

# ============================================================================
# Configure Tavily MCP
# ============================================================================
if (-not [string]::IsNullOrWhiteSpace($script:TavilyApiKey)) {
  Write-Info "Configuring Tavily MCP with your API key..."

  $mcpFile = $script:McpConfigFile
  $mcpDir = Split-Path $mcpFile -Parent
  if (-not (Test-Path $mcpDir)) {
    New-Item -ItemType Directory -Path $mcpDir -Force | Out-Null
  }

  # For JSON configs
  if ($mcpFile -match '\.json$') {
    try {
      $config = @{}
      if (Test-Path $mcpFile) {
        $config = Get-Content $mcpFile -Raw | ConvertFrom-Json | ConvertTo-Json -Depth 10 | ConvertFrom-Json
      }
      if (-not $config.PSObject.Properties['mcp']) {
        $config | Add-Member -NotePropertyName 'mcp' -NotePropertyValue ([ordered]@{})
      }
      $config.mcp | Add-Member -NotePropertyName 'tavily' -NotePropertyValue ([ordered]@{
        transport = 'http'
        url = "https://mcp.tavily.com/mcp/?tavilyApiKey=${script:TavilyApiKey}"
      })
      # Serialize to JSON
      $config | ConvertTo-Json -Depth 5 | Set-Content -Path $mcpFile -Encoding UTF8
      Write-Success "Tavily MCP configured ($mcpFile)"
    } catch {
      Write-Warn "Failed to write Tavily MCP config: $_"
    }
  }
}

# ============================================================================
# Dry run
# ============================================================================
if ($DryRun) {
  Write-Info "Dry run — showing what would be installed:"
  Write-Host ""
  Write-Host "  Install location: $($script:SkillDir)/"
  Write-Host "  Target agent:    $($script:AgentType)"
  Write-Host "  Main config:     $($script:MainInstructions)"
  Write-Host "  Required skills:"
  Write-Host "    • doit-skill (core)"
  Write-Host "    • grill-me (spec grilling)"
  Write-Host "    • tdd (test-driven development)"
  Write-Host "    • diagnose (bug diagnosis)"
  Write-Host "    • prototype (throwaway prototypes)"
  Write-Host "    • handoff (session handoff)"
  Write-Host "    • improve-codebase-architecture (architecture)"
  Write-Host ""

  if (-not $SkipOptional) {
    Write-Host "  External tools (installed via $($script:PkgMgr)):"
    Write-Host "    • context-mode     (Claude Code plugin)"
    Write-Host "    • rtk              (cargo install rtk or $($script:PkgMgr))"
    Write-Host "    • uv               (official installer)"
    Write-Host "    • rustup           (Rust toolchain)"
    Write-Host "    • lean-ctx         (curl installer)"
    Write-Host "    • headroom         (uv tool install)"
    Write-Host "    • codegraph        (npm i -g @colbymchenry/codegraph)"
    Write-Host "    • caveman          (Claude Code plugin)"
    Write-Host "    • code-review      (Claude Code plugin)"
    Write-Host "    • mempalace        (Claude Code plugin)"
  }

  Write-Host ""
  Write-Host "=========================================="
  Write-Info "Dry run complete"
  exit 0
}

# ============================================================================
# Clone repository
# ============================================================================
Write-Info "Cloning doit-skill repository..."
$TempDir = [System.IO.Path]::GetTempPath() + "doit-skill-install-$([Guid]::NewGuid())"
$DoitDir = Join-Path $TempDir "doit-skill"

try {
  # Ensure temp dir exists
  New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

  $cloneResult = git clone --depth 1 $script:REPO_URL $DoitDir 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to clone repository: $script:REPO_URL"
    Write-Error "Check your network connection, or try again later."
    exit 1
  }
  Write-Success "Repository cloned to $DoitDir"
} finally {
  # Cleanup temp dir on exit
  Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
  } | Out-Null
}

# ============================================================================
# Helper: Install skill
# ============================================================================
function Install-Skill {
  param(
    [string]$SkillName,
    [string]$SourceDir,
    [string]$TargetDir
  )

  $skillPath = Join-Path $TargetDir $SkillName

  if (Test-Path $skillPath) {
    $sourceSkill = Join-Path $SourceDir "skills/$SkillName"
    if (Test-Path $sourceSkill) {
      Write-Success "$SkillName already installed at $skillPath — updating..."
      # Remove old skill and copy new one
      Remove-Item -Path $skillPath -Recurse -Force
      Copy-Item -Path $sourceSkill -Destination $skillPath -Recurse -Force
      Write-Success "$SkillName updated"
    } else {
      Write-Success "$SkillName already installed at $skillPath"
    }
  } else {
    $sourceSkill = Join-Path $SourceDir "skills/$SkillName"
    if (Test-Path $sourceSkill) {
      Copy-Item -Path $sourceSkill -Destination $skillPath -Recurse -Force
      Write-Success "$SkillName installed"
    } else {
      Write-Error "$SkillName not found in repository"
      return $false
    }
  }

  return $true
}

# ============================================================================
# Helper: Compare snapshots (replaces comm/cut)
# ============================================================================
function Get-DirSnapshot {
  param([string]$Dir)

  $result = @()
  $items = Get-ChildItem -Path $Dir -Recurse -File -Force |
    Where-Object {
      $_.FullName -notmatch '\\(\.git|\.tokensave|\.claude\\skills)\\' -and
      -not $_.PSIsContainer
    } |
    Sort-Object FullName

  foreach ($file in $items) {
    $relativePath = $file.FullName.Replace($Dir + '\', '').Replace('\', '/')
    $hash = Get-FileHashPortable -Path $file.FullName
    $result += "$hash $relativePath"
  }

  return $result
}

function Compare-Snapshots {
  param(
    [string[]]$BeforeSnap,
    [string[]]$AfterSnap
  )

  $beforePaths = @{}
  $beforeHashes = @{}
  foreach ($line in $BeforeSnap) {
    $parts = $line -split ' ', 2
    $beforeHashes[$parts[1]] = $parts[0]
    $beforePaths[$parts[1]] = $true
  }

  $afterPaths = @{}
  $afterHashes = @{}
  foreach ($line in $AfterSnap) {
    $parts = $line -split ' ', 2
    $afterHashes[$parts[1]] = $parts[0]
    $afterPaths[$parts[1]] = $true
  }

  # New files
  foreach ($path in $afterPaths.Keys) {
    if (-not $beforePaths.ContainsKey($path)) {
      $script:UpdatedFiles += "$path (new)"
    }
  }

  # Removed files
  foreach ($path in $beforePaths.Keys) {
    if (-not $afterPaths.ContainsKey($path)) {
      $script:UpdatedFiles += "$path (removed)"
    }
  }

  # Modified files
  foreach ($path in $afterPaths.Keys) {
    if ($beforePaths.ContainsKey($path) -and
        $beforeHashes[$path] -ne $afterHashes[$path]) {
      $script:UpdatedFiles += "$path (modified)"
    }
  }
}

# ============================================================================
# Step 1: Install required skills
# ============================================================================
Write-Host "=========================================="
Write-Host "  Step 1: Installing required skills"
Write-Host "=========================================="
Write-Host ""

$DoitDst = $script:SkillDir + "/doit"
if (-not (Test-Path (Split-Path $DoitDst -Parent))) {
  New-Item -ItemType Directory -Path (Split-Path $DoitDst -Parent) -Force | Out-Null
}

if (Test-Path $DoitDst) {
  Write-Success "doit already installed at $DoitDst — updating..."

  # Snapshot before
  $beforeSnap = Get-DirSnapshot -Dir $DoitDst

  # Incremental update: copy new/changed files
  # Use robocopy for efficient mirroring (preserves symlinks better than Copy-Item)
  $excludeItems = @('.git', '.tokensave', '.claude\skills', 'skills', '.doit')
  $robocopyArgs = @($DoitDir, $DoitDst, '/MIR', '/NFL', '/NDL', '/NJH', '/NJS') +
    ($excludeItems | ForEach-Object { "/XD:$_" })

  robocopy @robocopyArgs | Out-Null

  # If robocopy not available, fallback to Copy-Item
  if (-not (Test-Command robocopy)) {
    # Copy all files except excluded directories
    Copy-Item -Path "$DoitDir\*" -Destination $DoitDst -Recurse -Force
    foreach ($ex in $excludeItems) {
      $exPath = Join-Path $DoitDst $ex
      if (Test-Path $exPath) { Remove-Item -Path $exPath -Recurse -Force }
    }
  }

  # Snapshot after + compare
  $afterSnap = Get-DirSnapshot -Dir $DoitDst
  Compare-Snapshots -BeforeSnap $beforeSnap -AfterSnap $afterSnap

  # Fix symlinks (Windows: use real files instead of symlinks)
  $symlinkFiles = @("review-simplify.md", "commit.md")
  foreach ($lnk in $symlinkFiles) {
    $linkPath = Join-Path $DoitDst $lnk
    $targetRel = "core/shared/$lnk"
    $targetPath = Join-Path $DoitDst $targetRel

    if (Test-Path $targetPath) {
      # On Windows, create a hard link or just copy (symlinks require admin)
      if ($script:IsAdmin) {
        # Try symlink first
        try {
          if (Test-Path $linkPath) { Remove-Item $linkPath -Force }
          New-Item -ItemType SymbolicLink -Path $linkPath -Target $targetPath -Force | Out-Null
          $script:UpdatedFiles += "$lnk (symlink created)"
          Write-Success "$lnk -> symlink to $targetRel"
        } catch {
          # Fallback to hard link
          try {
            if (Test-Path $linkPath) { Remove-Item $linkPath -Force }
            New-Item -ItemType HardLink -Path $linkPath -Target $targetPath -Force | Out-Null
            Write-Success "$lnk -> hard link to $targetRel"
          } catch {
            # Last resort: copy
            Copy-Item -Path $targetPath -Destination $linkPath -Force
            Write-Success "$lnk -> copied from $targetRel"
          }
        }
      } else {
        # No admin: copy the file
        Copy-Item -Path $targetPath -Destination $linkPath -Force
        Write-Success "$lnk -> copied from $targetRel (no symlink perms)"
      }
    }
  }

  # Clean excluded dirs
  foreach ($ex in @('.git', '.tokensave', '.claude\skills', 'skills', '.doit')) {
    $exPath = Join-Path $DoitDst $ex
    if (Test-Path $exPath) { Remove-Item -Path $exPath -Recurse -Force }
  }
} else {
  # Fresh install
  Copy-Item -Path "$DoitDir\*" -Destination $DoitDst -Recurse -Force

  # Clean excluded dirs
  foreach ($ex in @('.git', '.tokensave', '.claude\skills', 'skills', '.doit')) {
    $exPath = Join-Path $DoitDst $ex
    if (Test-Path $exPath) { Remove-Item -Path $exPath -Recurse -Force }
  }

  Write-Success "doit installed"
}

# Verify symlinks
Write-Host ""
foreach ($lnk in @("review-simplify.md", "commit.md")) {
  $linkPath = Join-Path $DoitDst $lnk
  if (Test-Path $linkPath) {
    $item = Get-Item $linkPath
    if ($item.Target) {
      Write-Success "$lnk -> $($item.Target) (symlink OK)"
    } elseif ($item.LinkType) {
      Write-Success "$lnk -> $($item.LinkType) OK"
    } else {
      Write-Success "$lnk exists (regular file)"
    }
  } else {
    Write-Warn "$lnk not found — some shared phases may not work"
  }
}

# Install bundled skills
Write-Host ""
$bundledSkills = @(
  "grill-me",
  "tdd",
  "diagnose",
  "prototype",
  "handoff",
  "improve-codebase-architecture"
)

foreach ($skill in $bundledSkills) {
  Install-Skill -SkillName $skill -SourceDir $DoitDir -TargetDir $script:SkillDir

  # Ensure .claude-plugin directory is copied
  $pluginSrc = Join-Path $DoitDir "skills/$skill/.claude-plugin"
  $pluginDst = Join-Path $script:SkillDir "$skill/.claude-plugin"
  if (Test-Path $pluginSrc) {
    if (-not (Test-Path (Split-Path $pluginDst -Parent))) {
      New-Item -ItemType Directory -Path (Split-Path $pluginDst -Parent) -Force | Out-Null
    }
    Copy-Item -Path "$pluginSrc\*" -Destination $pluginDst -Recurse -Force
  }

  Write-Success "$skill ready (SKILL.md at root)"
}

Write-Host ""

# ============================================================================
# Step 2: Install optional skills
# ============================================================================
if ($SkipOptional) {
  Write-Host "=========================================="
  Write-Host "  Step 2: Skipping optional skills (-SkipOptional)"
  Write-Host "=========================================="
  Write-Host ""
} else {
  Write-Host "=========================================="
  Write-Host "  Step 2: Installing optional skills"
  Write-Host "=========================================="
  Write-Host ""

  # Skill-Creator (requires npx)
  if (Test-Command npx) {
    $scInstalled = $false
    try {
      $listOutput = npx skills list 2>&1
      if ($listOutput -match 'skill-creator') { $scInstalled = $true }
    } catch { }

    # Fallback: check common paths
    if (-not $scInstalled) {
      if ((Test-Path "$HOME/.agents/skills/skill-creator") -or
          (Test-Path ".agents/skills/skill-creator")) {
        $scInstalled = $true
      }
    }

    if ($scInstalled) {
      if ($SkipUpdates) {
        Write-Skip "skill-creator already installed (skipping update)"
      } else {
        Write-Info "Updating skill-creator..."
        npx skills add anthropics/skills@skill-creator -y --non-interactive 2>$null
        if ($LASTEXITCODE -ne 0) {
          Write-Warn "Failed to update skill-creator (non-blocking)"
        }
      }
    } else {
      Write-Info "Installing skill-creator..."
      npx skills add anthropics/skills@skill-creator -y --non-interactive 2>$null
      if ($LASTEXITCODE -ne 0) {
        Write-Warn "Failed to install skill-creator (non-blocking)"
      }
    }
  } else {
    Write-Warn "npx not found — skill-creator requires Node.js. Install manually:"
    Write-Host "     npx skills add anthropics/skills@skill-creator"
  }
}

# ============================================================================
# Helper: Install external tool via package manager
# ============================================================================
function Install-Tool {
  param(
    [string]$Name,
    [string]$WingetId,
    [string]$ChocoId,
    [string]$ScoopId,
    [scriptblock]$Fallback = $null,
    [int]$TimeoutSeconds = 180
  )

  # Check if already installed
  if (Test-Command $Name) {
    if ($SkipUpdates) {
      Write-Skip "$Name already installed (skipping update)"
      return $true
    }
    Write-Info "Updating $Name..."
  } else {
    Write-Info "Installing $Name..."
  }

  $success = $false

  switch ($script:PkgMgr) {
    "winget" {
      $id = $WingetId
      if ([string]::IsNullOrWhiteSpace($id)) { $id = $Name }
      Write-Host "     > winget install --id $id --accept-source-agreements --accept-package-agreements --silent"
      winget install --id $id --accept-source-agreements --accept-package-agreements --silent 2>&1
      if ((Test-Command $Name) -or ($LASTEXITCODE -eq 0)) { $success = $true }
    }
    "choco" {
      $id = $ChocoId
      if ([string]::IsNullOrWhiteSpace($id)) { $id = $Name }
      Write-Host "     > choco install $id -y"
      choco install $id -y 2>&1
      if ((Test-Command $Name) -or ($LASTEXITCODE -eq 0)) { $success = $true }
    }
    "scoop" {
      $id = $ScoopId
      if ([string]::IsNullOrWhiteSpace($id)) { $id = $Name }
      Write-Host "     > scoop install $id"
      scoop install $id 2>&1
      if ((Test-Command $Name) -or ($LASTEXITCODE -eq 0)) { $success = $true }
    }
  }

  # Fallback: direct download or alternative install method
  if (-not $success -and $Fallback) {
    Write-Info "Falling back to alternative install method..."
    & $Fallback
    if (Test-Command $Name) { $success = $true }
  }

  if ($success) {
    Write-Success "$Name installed"
    return $true
  } else {
    Write-Warn "Failed to install $Name — install manually"
    return $false
  }
}

# ============================================================================
# Helper: Install tool via direct download (for tools without pkg manager ID)
# ============================================================================
function Download-AndInstall {
  param(
    [string]$Url,
    [string]$FileName,
    [string]$TargetDir,
    [string]$TestCmd
  )

  # Ensure target directory exists
  if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
  }

  $targetPath = Join-Path $TargetDir $FileName
  Write-Host "     > Downloading from $Url"

  try {
    # Use Invoke-WebRequest for downloading
    if ($IsWindows) {
      # Native Windows: use .NET WebClient for better progress
      $webClient = New-Object System.Net.WebClient
      $webClient.DownloadFile($Url, $targetPath)
    } else {
      Invoke-WebRequest -Uri $Url -OutFile $targetPath -UseBasicParsing
    }
    Write-Success "Downloaded to $targetPath"
    return $true
  } catch {
    Write-Warn "Download failed: $_"
    return $false
  }
}

# ============================================================================
# Check if all tools already installed
# ============================================================================
$skipStep3 = $false
$installedCount = 0
$toolChecks = @("rtk", "uv", "cargo", "lean-ctx", "codegraph", "headroom")
foreach ($tool in $toolChecks) {
  if (Test-Command $tool) { $installedCount++ }
}

# Check for Claude Code plugins
$pluginsDir = "$HOME/.claude/plugins"
if (Test-Path $pluginsDir) {
  if (Get-ChildItem -Path $pluginsDir -Recurse -Filter "*context-mode*" -ErrorAction SilentlyContinue) {
    $installedCount++
  }
  if (Get-ChildItem -Path $pluginsDir -Recurse -Filter "*caveman*" -ErrorAction SilentlyContinue) {
    $installedCount++
  }
}

if ($installedCount -ge 9) {
  $skipStep3 = $true
  Write-Skip "All tools installed — skipping Step 3 (-SkipUpdates to force)"
  Write-Host ""
}

# ============================================================================
# Step 3: Install external tools
# ============================================================================
if ($SkipOptional) {
  Write-Host "=========================================="
  Write-Host "  Step 3: Skipping external tools (-SkipOptional)"
  Write-Host "=========================================="
  Write-Host ""
} elseif (-not $skipStep3) {
  Write-Host "=========================================="
  Write-Host "  Step 3: Installing external tools"
  Write-Host "=========================================="
  Write-Host ""

  # Ensure $HOME\.local\bin is in PATH
  $localBin = Join-Path $HOME ".local\bin"
  if ($env:PATH -notmatch [regex]::Escape($localBin)) {
    $env:PATH = "$localBin;$env:PATH"
    # Persist to PowerShell profile
    $profileDir = Split-Path $PROFILE -Parent
    if (-not (Test-Path $profileDir)) {
      New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }
    $persistLine = "`n`n# doit-skill: add .local/bin to PATH`nif (`$env:PATH -notmatch [regex]::Escape('$localBin')) {`n  `$env:PATH = '$localBin';`$env:PATH`n}"
    if (-not (Test-Path $PROFILE) -or (Get-Content $PROFILE -Raw) -notmatch '\.local\\bin') {
      Add-Content -Path $PROFILE -Value $persistLine -Encoding UTF8
    }
  }

  # =========================================================================
  # Context-Mode (Claude Code plugin)
  # =========================================================================
  if ($script:AgentType -eq "claude") {
    $hasCtxMode = $false
    if (Test-Path $pluginsDir) {
      $hasCtxMode = (Get-ChildItem -Path $pluginsDir -Recurse -Filter "*context-mode*" -ErrorAction SilentlyContinue).Count -gt 0
    }

    if ($hasCtxMode) {
      if ($SkipUpdates) {
        Write-Skip "context-mode already installed (skipping update)"
      } else {
        Write-Info "Updating context-mode..."
        claude plugin install context-mode@context-mode 2>$null
        if ($LASTEXITCODE -eq 0) { Write-Success "context-mode updated" }
        else { Write-Warn "context-mode update failed" }
      }
    } else {
      Write-Info "Installing context-mode..."
      claude plugin marketplace add mksglu/context-mode 2>$null
      claude plugin install context-mode@context-mode 2>$null
    }
  } else {
    Write-Info "context-mode is a Claude Code plugin — skipping for $($script:AgentType)"
  }

  # =========================================================================
  # RTK (Rust Token Killer)
  # =========================================================================
  if (Test-Command rtk) {
    if ($SkipUpdates) {
      Write-Skip "rtk already installed (skipping update)"
    } else {
      Write-Info "Updating rtk..."
      if (Test-Command cargo) {
        Write-Host "     > cargo install rtk"
        cargo install rtk 2>&1
      }
      # Fallback: download prebuilt binary
      if (-not (Test-Command rtk)) {
        Write-Info "Falling back to curl install script..."
        $installScriptUrl = "${script:GH_PROXY}/https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh"
        # On Windows, download the binary directly
        $rtkBinUrl = "https://github.com/rtk-ai/rtk/releases/latest/download/rtk-x86_64-pc-windows-msvc.exe"
        try {
          Invoke-WebRequest -Uri $rtkBinUrl -OutFile (Join-Path $localBin "rtk.exe") -UseBasicParsing
          Write-Success "rtk downloaded (Windows binary)"
        } catch {
          Write-Warn "Failed to download rtk Windows binary: $_"
        }
      }
    }
  } else {
    Write-Info "Installing rtk..."
    if (Test-Command cargo) {
      Write-Host "     > cargo install rtk"
      cargo install rtk 2>&1
    }
    if (-not (Test-Command rtk)) {
      Write-Info "Attempting Windows binary download..."
      $rtkBinUrl = "https://github.com/rtk-ai/rtk/releases/latest/download/rtk-x86_64-pc-windows-msvc.exe"
      try {
        Invoke-WebRequest -Uri $rtkBinUrl -OutFile (Join-Path $localBin "rtk.exe") -UseBasicParsing
        Write-Success "rtk downloaded (Windows binary)"
      } catch {
        Write-Warn "Failed to download rtk. Install with: cargo install rtk"
      }
    }
  }

  if (Test-Command rtk) {
    Write-Info "Initializing rtk for $($script:AgentType)..."
    rtk init -g 2>$null
    Write-Success "rtk installed and initialized"
  }

  # =========================================================================
  # UV (Python package manager)
  # =========================================================================
  if (Test-Command uv) {
    if ($SkipUpdates) {
      Write-Skip "uv already installed (skipping update)"
    } else {
      Write-Info "Updating uv..."
      uv self update 2>&1
    }
  } else {
    Write-Info "Installing uv..."
    # Windows native installer
    $uvInstallerUrl = "https://astral.sh/uv/installer/x86_64-pc-windows-msvc/uv.exe"
    $uvPath = Join-Path $localBin "uv.exe"
    try {
      Invoke-WebRequest -Uri $uvInstallerUrl -OutFile $uvPath -UseBasicParsing
      Write-Success "uv downloaded to $uvPath"
    } catch {
      # Fallback: pip install
      Write-Info "Direct download failed, trying pip..."
      pip install uv 2>&1
    }
  }

  # Configure uv PyPI mirror (Tsinghua)
  if (Test-Command uv) {
    $uvConfigDir = Join-Path $HOME ".config/uv"
    $uvConfigPath = Join-Path $uvConfigDir "uv.toml"
    if (-not (Test-Path $uvConfigDir)) {
      New-Item -ItemType Directory -Path $uvConfigDir -Force | Out-Null
    }
    if (-not (Test-Path $uvConfigPath) -or
        (Get-Content $uvConfigPath -Raw) -notmatch 'pypi.tuna.tsinghua.edu.cn') {
      @"
[[index]]
url = "https://pypi.tuna.tsinghua.edu.cn/simple"
default = true
"@ | Set-Content -Path $uvConfigPath -Encoding UTF8
      Write-Success "uv PyPI mirror configured (Tsinghua)"
    }
  }

  # =========================================================================
  # Rust (via rustup)
  # =========================================================================
  if (Test-Command cargo) {
    Write-Info "Updating Rust via rustup..."
    $env:RUSTUP_DIST_SERVER = "https://mirrors.tuna.tsinghua.edu.cn/rustup"
    $env:RUSTUP_UPDATE_ROOT = "https://mirrors.tuna.tsinghua.edu.cn/rustup/rustup"
    rustup update stable 2>&1
    Write-Success "Rust updated"
  } else {
    Write-Info "Installing Rust via rustup..."
    $rustupPath = Join-Path $localBin "rustup-init.exe"
    try {
      Invoke-WebRequest -Uri "https://mirrors.tuna.tsinghua.edu.cn/rustup/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe" -OutFile $rustupPath -UseBasicParsing
      & $rustupPath -y --dist-server https://mirrors.tuna.tsinghua.edu.cn/rustup 2>&1
      Remove-Item $rustupPath -ErrorAction SilentlyContinue

      # Source cargo env
      $cargoEnv = Join-Path $HOME ".cargo/env"
      if (Test-Path $cargoEnv) {
        . $cargoEnv
      } else {
        $cargoBin = Join-Path $HOME ".cargo\bin"
        if ($env:PATH -notmatch [regex]::Escape($cargoBin)) {
          $env:PATH = "$cargoBin;$env:PATH"
        }
      }

      if (Test-Command cargo) { Write-Success "Rust installed" }
    } catch {
      Write-Warn "Failed to install Rust: $_"
      Write-Host "     Install manually: https://www.rust-lang.org/tools/install"
    }

    # Configure cargo mirror (USTC)
    $cargoDir = Join-Path $HOME ".cargo"
    $cargoConfig = Join-Path $cargoDir "config.toml"
    if (-not (Test-Path $cargoDir)) {
      New-Item -ItemType Directory -Path $cargoDir -Force | Out-Null
    }
    @"
[source.crates-io]
replace-with = 'ustc'
[source.ustc]
registry = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"
"@ | Set-Content -Path $cargoConfig -Encoding UTF8
    Write-Success "cargo mirror configured (USTC)"
  }

  # =========================================================================
  # Caveman (Claude Code plugin)
  # =========================================================================
  if ($script:AgentType -eq "claude") {
    $hasCaveman = $false
    if (Test-Path $pluginsDir) {
      $hasCaveman = (Get-ChildItem -Path $pluginsDir -Recurse -Filter "*caveman*" -ErrorAction SilentlyContinue).Count -gt 0
    }

    if ($hasCaveman) {
      if ($SkipUpdates) {
        Write-Skip "caveman already installed (skipping update)"
      } else {
        Write-Info "Updating caveman..."
        claude plugin install caveman@caveman 2>$null
        Write-Success "caveman updated"
      }
    } else {
      Write-Info "Installing caveman..."
      claude plugin marketplace add JuliusBrussee/caveman 2>$null
      claude plugin install caveman@caveman 2>$null
      if ($LASTEXITCODE -ne 0) {
        Write-Warn "claude plugin install failed, trying npx fallback..."
        # Fallback: download install script
        $installScript = "${script:GH_PROXY}/https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh"
        try {
          $scriptContent = Invoke-WebRequest -Uri $installScript -UseBasicParsing
          Write-Success "caveman install script downloaded"
        } catch {
          Write-Warn "Failed to install caveman"
        }
      }
    }

    # Caveman hooks + statusline
    $hooksDir = "$HOME/.claude/hooks"
    $hasStatuslineHook = $false
    if (Test-Path $hooksDir) {
      $hasStatuslineHook = (Get-ChildItem -Path $hooksDir -Filter "*caveman-statusline*" -ErrorAction SilentlyContinue).Count -gt 0
    }

    if (-not $hasStatuslineHook) {
      Write-Info "Installing caveman hooks (statusline)..."
      $installScript = "${script:GH_PROXY}/https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh"
      try {
        # Download and run with --with-hooks --skip-skills
        Write-Warn "caveman hooks require bash — run in Git Bash or WSL: bash install.sh --with-hooks --skip-skills"
      } catch {
        Write-Warn "caveman hook install failed — statusline not configured"
      }
    } else {
      Write-Success "caveman statusline hooks already installed"
    }

    # Configure caveman statusline in settings.json
    $claudeSettings = "$HOME/.claude/settings.json"
    if (Test-Path $claudeSettings) {
      try {
        $settings = Get-Content $claudeSettings -Raw | ConvertFrom-Json
        $slCommand = $null
        if ($settings.statusLine -and $settings.statusLine.command) {
          $slCommand = $settings.statusLine.command
        }

        if ($slCommand -notmatch 'caveman-statusline') {
          $hooksDirAbs = "$HOME/.claude/hooks"
          $slScript = Join-Path $hooksDirAbs "caveman-statusline.sh"
          if (Test-Path $slScript) {
            $settings.statusLine = @{
              type = "command"
              command = "bash `"$slScript`""
            }
            $settings | ConvertTo-Json -Depth 5 | Set-Content -Path $claudeSettings -Encoding UTF8
            Write-Success "caveman statusline configured"
          } else {
            Write-Warn "caveman-statusline.sh not found — install hooks first"
          }
        } else {
          Write-Success "caveman statusline already configured"
        }
      } catch {
        Write-Warn "Failed to configure caveman statusline: $_"
      }
    }
  } else {
    Write-Info "caveman is a Claude Code plugin — skipping for $($script:AgentType)"
  }

  # =========================================================================
  # Code Review (Claude Code plugin)
  # =========================================================================
  if ($script:AgentType -eq "claude") {
    $hasCodeReview = $false
    if (Test-Path $pluginsDir) {
      $hasCodeReview = (Get-ChildItem -Path $pluginsDir -Recurse -Filter "*code-review*" -ErrorAction SilentlyContinue).Count -gt 0
    }

    if ($hasCodeReview) {
      if ($SkipUpdates) {
        Write-Skip "code-review already installed (skipping update)"
      } else {
        Write-Info "Updating code-review..."
        claude plugin install code-review 2>$null
        Write-Success "code-review updated"
      }
    } else {
      Write-Info "Installing code-review..."
      claude plugin install code-review 2>$null
    }
  } else {
    Write-Info "code-review is a Claude Code plugin — skipping for $($script:AgentType)"
  }

  # =========================================================================
  # MemPalace (Claude Code plugin + CLI)
  # =========================================================================
  if ($script:AgentType -eq "claude") {
    $hasMemPalace = $false
    if (Test-Path $pluginsDir) {
      $hasMemPalace = (Get-ChildItem -Path $pluginsDir -Recurse -Filter "*mempalace*" -ErrorAction SilentlyContinue).Count -gt 0
    }

    if ($hasMemPalace) {
      if ($SkipUpdates) {
        Write-Skip "mempalace already installed (skipping update)"
      } else {
        Write-Info "Updating mempalace..."
        claude plugin install --scope user mempalace 2>$null
        Write-Success "mempalace updated"
      }
    } else {
      Write-Info "Installing mempalace..."
      claude plugin marketplace add MemPalace/mempalace 2>$null
      claude plugin install --scope user mempalace 2>$null
    }
  } else {
    Write-Info "mempalace Claude Code plugin — skipping for $($script:AgentType)"
  }

  # MemPalace CLI (uv tool)
  if (Test-Command uv) {
    if (Test-Command mempalace) {
      if ($SkipUpdates) {
        Write-Skip "mempalace CLI already installed (skipping update)"
      } else {
        Write-Info "Updating mempalace CLI..."
        uv tool install mempalace 2>&1
        Write-Success "mempalace CLI updated"
      }
    } else {
      Write-Info "Installing mempalace CLI..."
      uv tool install mempalace 2>&1
    }
  }

  # MemPalace init
  if ((Test-Path "mempalace.yaml") -or (Test-Path ".mempalace")) {
    Write-Success "mempalace already initialized"
  } elseif (Test-Command mempalace) {
    Write-Info "Initializing mempalace (creating HNSW index)..."
    mempalace init . --yes 2>&1
    if (Test-Path "mempalace.yaml") {
      Write-Info "Mining mempalace index..."
      mempalace mine . 2>&1
    }
  }

  # =========================================================================
  # lean-ctx (context optimization)
  # =========================================================================
  Write-Host "=========================================="
  Write-Host "  Step 3.6: Installing lean-ctx"
  Write-Host "=========================================="
  Write-Host ""

  if (Test-Command lean-ctx) {
    if ($SkipUpdates) {
      Write-Skip "lean-ctx already installed (skipping update)"
    } else {
      Write-Info "Updating lean-ctx..."
      # lean-ctx has a PowerShell installer
      $leanCtxUrl = "https://leanctx.com/install.ps1"
      try {
        Invoke-WebRequest -Uri $leanCtxUrl -OutFile (Join-Path $env:TEMP "lean-ctx-install.ps1") -UseBasicParsing
        & (Join-Path $env:TEMP "lean-ctx-install.ps1") 2>&1
        Remove-Item (Join-Path $env:TEMP "lean-ctx-install.ps1") -ErrorAction SilentlyContinue
      } catch {
        # Fallback: download binary directly
        Write-Info "Trying direct download..."
        $leanCtxBinUrl = "https://leanctx.com/install.sh"
        Write-Warn "lean-ctx installer requires bash on Windows — run in Git Bash: curl -fsSL https://leanctx.com/install.sh | bash"
      }
    }
  } else {
    Write-Info "Installing lean-ctx..."
    $leanCtxUrl = "https://leanctx.com/install.ps1"
    try {
      Invoke-WebRequest -Uri $leanCtxUrl -OutFile (Join-Path $env:TEMP "lean-ctx-install.ps1") -UseBasicParsing
      & (Join-Path $env:TEMP "lean-ctx-install.ps1") 2>&1
      Remove-Item (Join-Path $env:TEMP "lean-ctx-install.ps1") -ErrorAction SilentlyContinue
    } catch {
      Write-Warn "lean-ctx installer requires bash on Windows — run in Git Bash: curl -fsSL https://leanctx.com/install.sh | bash"
    }
  }

  if (Test-Command lean-ctx) {
    lean-ctx --version 2>&1
    Write-Info "Connecting lean-ctx to all AI tools..."
    lean-ctx onboard 2>&1

    # lean-ctx project rules
    $leanCtxGlobalRules = "$HOME/.claude/rules/lean-ctx.md"
    $projectRulesDir = ".claude/rules"
    $projectRulesFile = Join-Path $projectRulesDir "lean-ctx.md"

    if (Test-Path $leanCtxGlobalRules) {
      if (-not (Test-Path $projectRulesDir)) {
        New-Item -ItemType Directory -Path $projectRulesDir -Force | Out-Null
      }
      Copy-Item -Path $leanCtxGlobalRules -Destination $projectRulesFile -Force
      Write-Success "lean-ctx project rules configured ($projectRulesFile)"
    }

    # lean-ctx project hooks
    $projectSettingsFile = ".claude/settings.local.json"
    if (-not (Test-Path $projectSettingsFile)) {
      $settingsDir = ".claude"
      if (-not (Test-Path $settingsDir)) {
        New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
      }

      $localSettings = @{
        hooks = @{
          PostToolUse = @(
            @{ hooks = @(
                @{ command = "lean-ctx hook observe"; type = "command" }
              ); matcher = ".*" }
          )
          PreCompact = @(
            @{ hooks = @(
                @{ command = "lean-ctx hook observe"; type = "command" }
              ); matcher = ".*" }
          )
          PreToolUse = @(
            @{ hooks = @(
                @{ command = "lean-ctx hook rewrite"; type = "command" }
              ); matcher = "Bash|bash" },
            @{ hooks = @(
                @{ command = "lean-ctx hook redirect"; type = "command" }
              ); matcher = "Read|read|ReadFile|read_file|View|view|Grep|grep|Search|search|ListFiles|list_files|ListDirectory|list_directory" }
          )
          Stop = @(
            @{ hooks = @(
                @{ command = "lean-ctx hook observe"; type = "command" }
              ); matcher = ".*" }
          )
          UserPromptSubmit = @(
            @{ hooks = @(
                @{ command = "lean-ctx hook observe"; type = "command" }
              ); matcher = ".*" }
          )
        }
      }
      $localSettings | ConvertTo-Json -Depth 5 | Set-Content -Path $projectSettingsFile -Encoding UTF8
      Write-Success "lean-ctx project hooks configured ($projectSettingsFile)"
    } else {
      Write-Success "lean-ctx project hooks already configured"
    }

    Write-Success "lean-ctx installed"
  }

  # =========================================================================
  # Headroom (token optimization)
  # =========================================================================
  Write-Host "=========================================="
  Write-Host "  Step 3.7: Installing headroom"
  Write-Host "=========================================="
  Write-Host ""

  # Check Python version
  $pythonOk = $false
  if (Test-Command python3) {
    $pyVersion = python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
    if ($pyVersion) {
      $parts = $pyVersion -split '\.'
      if (($parts[0] -eq 3) -and ($parts[1] -ge 10)) { $pythonOk = $true }
    }
  } elseif (Test-Command python) {
    $pyVersion = python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
    if ($pyVersion) {
      $parts = $pyVersion -split '\.'
      if (($parts[0] -eq 3) -and ($parts[1] -ge 10)) { $pythonOk = $true }
    }
  }

  if (-not $pythonOk) {
    Write-Warn "Python >= 3.10 not found — skipping headroom (requires CPython >= 3.10)"
  } else {
    # Headroom via uv
    if (Test-Command uv) {
      if (Test-Command headroom) {
        if ($SkipUpdates) {
          Write-Skip "headroom already installed (skipping update)"
        } else {
          Write-Info "Updating headroom..."
          uv tool install "headroom-ai[mcp,proxy]" 2>&1
          Write-Success "headroom updated"
        }
      } else {
        Write-Info "Installing headroom..."
        uv tool install "headroom-ai[mcp,proxy]" 2>&1
      }
    } else {
      Write-Warn "uv not found — install headroom manually: uv tool install 'headroom-ai[mcp,proxy]'"
    }

    if (Test-Command headroom) {
      if ($script:AgentType -eq "claude") {
        $mcpList = claude mcp list 2>$null
        if ($mcpList -match 'headroom') {
          Write-Success "headroom MCP already configured"
        } else {
          Write-Info "Configuring headroom MCP..."
          headroom mcp install 2>&1
        }
      } else {
        Write-Info "headroom MCP — configure manually for $($script:AgentType)"
      }
    }
  }

  # =========================================================================
  # CodeGraph (pre-built code graph index)
  # =========================================================================
  Write-Host "=========================================="
  Write-Host "  Step 3.8: Installing CodeGraph"
  Write-Host "=========================================="
  Write-Host ""

  if (Test-Command codegraph) {
    if ($SkipUpdates) {
      Write-Skip "codegraph already installed (skipping update)"
    } else {
      Write-Info "Updating codegraph..."
      npm i -g @colbymchenry/codegraph 2>&1
    }
  } else {
    Write-Info "Installing codegraph..."
    npm i -g @colbymchenry/codegraph 2>&1
  }

  if (Test-Command codegraph) {
    # Install MCP server
    if ($script:AgentType -eq "claude") {
      $mcpList = claude mcp list 2>$null
      if ($mcpList -match 'codegraph') {
        Write-Success "codegraph MCP already configured"
      } else {
        Write-Info "Configuring codegraph MCP server..."
        codegraph install --yes 2>&1
        $mcpList = claude mcp list 2>$null
        if ($mcpList -match 'codegraph') {
          Write-Success "codegraph MCP configured"
        } else {
          Write-Warn "codegraph MCP not detected — run: codegraph install --yes"
        }
      }
    } else {
      Write-Info "codegraph MCP — configure manually for $($script:AgentType)"
    }

    # Initialize project index
    if (Test-Path ".codegraph") {
      Write-Success "codegraph index already exists"
    } else {
      Write-Info "Initializing codegraph index..."
      codegraph init -i 2>&1
      if (Test-Path ".codegraph") {
        Write-Success "codegraph index initialized"
      }
    }
  }

  # =========================================================================
  # Start Headroom Proxy
  # =========================================================================
  $hrProxyEnabled = Get-ConfigValue -Key "enabled"
  if ((Test-Path $ConfigPath)) {
    $configContent = Get-Content $ConfigPath -Raw
    if ($configContent -match '(?s)proxy:.*?enabled:\s*(\w+)') {
      $hrProxyEnabled = $Matches[1].ToLower()
    }
  }

  if ($hrProxyEnabled -eq "true" -and (Test-Command headroom)) {
    $hrPort = 8787
    if ($configContent -match '(?s)proxy:.*?port:\s*(\d+)') {
      $hrPort = [int]$Matches[1]
    }

    Write-Info "Starting headroom proxy on port $hrPort..."
    Start-Process -FilePath "headroom" -ArgumentList "proxy", "--port", "$hrPort" -WindowStyle Hidden
    $env:ANTHROPIC_BASE_URL = "http://127.0.0.1:${hrPort}"
    Write-Success "headroom proxy started (port $hrPort)"
    Write-Info "All tool outputs now auto-compressed (60-95% token savings)"
  }
}

# ============================================================================
# Step 4: Run doctor
# ============================================================================
Write-Host "=========================================="
Write-Host "  Step 4: Running dependency check"
Write-Host "=========================================="
Write-Host ""

$doctorScript = Join-Path (Join-Path $script:SkillDir "doit/scripts") "doctor.ps1"
$doctorShScript = Join-Path (Join-Path $script:SkillDir "doit/scripts") "doctor.sh"

if (Test-Path $doctorScript) {
  & $doctorScript
} elseif (Test-Path $doctorShScript) {
  Write-Warn "doctor.ps1 not found — doctor.sh requires bash (Git Bash, WSL, or MSYS2)"
  Write-Host "     Run: bash $doctorShScript"
} else {
  Write-Warn "doctor script not found, skipping dependency check"
}

# Cleanup
Write-Host ""
Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue

# ============================================================================
# Summary
# ============================================================================
Write-Host "=========================================="
if ($script:UpdatedFiles.Count -gt 0) {
  Write-Host "  ✅ doit-skill updated!"
  Write-Host "=========================================="
  Write-Host ""

  $uniqueFiles = $script:UpdatedFiles | Sort-Object -Unique
  Write-Host "  Changed files ($($uniqueFiles.Count)):"
  foreach ($f in $uniqueFiles) {
    Write-Host "    • $f"
  }
  Write-Host ""
} else {
  Write-Host "  ✅ doit-skill installation complete!"
  Write-Host "=========================================="
  Write-Host ""
}

# Show current configuration
Write-Host "  [CONFIG] Current doit configuration:"
$docCap = (Get-Content $ConfigPath -Raw) -match '(?m)doc-capture:.*?enabled:\s*(\w+)' ? $Matches[1] : "true"
$subagent = (Get-Content $ConfigPath -Raw) -match '(?m)subagent:.*?enabled:\s*(\w+)' ? $Matches[1] : "false"
$autoCmt = (Get-Content $ConfigPath -Raw) -match '(?m)auto_commit:.*?enabled:\s*(\w+)' ? $Matches[1] : "false"

Write-Host "    doc-capture.enabled: $docCap"
Write-Host "    subagent.enabled: $subagent"
Write-Host "    auto_commit.enabled: $autoCmt"
Write-Host ""
Write-Host "  To update: re-run this script (powershell -ExecutionPolicy Bypass -File scripts/setup.ps1)"
Write-Host "  To check dependencies: scripts/doctor.ps1"
Write-Host "  To change config: edit $ConfigPath"
Write-Host ""
