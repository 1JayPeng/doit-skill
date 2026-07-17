<#
.SYNOPSIS
  doit-skill Doctor - Check dependencies and installation status (PowerShell)

.DESCRIPTION
  Checks doit skill installation, bundled skills, and external tools.
  PowerShell-native equivalent of scripts/doctor.sh.

.EXAMPLE
  .\scripts\doctor.ps1
#>

# Detect skill directory: multi-CLI support
$skillDirs = @(
  ".claude/skills",
  ".opencode/skills",
  ".omp/skills",
  ".mimo/skills",
  ".jcode/skills",
  "$HOME/.claude/skills",
  "$HOME/.opencode/skills",
  "$HOME/.config/omp/skills",
  "$HOME/.config/mimo/skills",
  "$HOME/.jcode/skills"
)

$SkillDir = $null
foreach ($dir in $skillDirs) {
  if (Test-Path $dir) {
    $SkillDir = $dir
    break
  }
}

if (-not $SkillDir) { $SkillDir = ".claude/skills" }

$GH_PROXY = "https://v6.gh-proxy.org"
$bundledSkills = @("grill-me", "tdd", "diagnose", "prototype", "handoff", "improve-codebase-architecture")
$coreFiles = @(
  "SKILL.md",
  "core/iron-rules.md",
  "core/workflow.md",
  "classifier.md",
  "spec.md",
  "plan.md",
  "core/execute.md",
  "e2e.md",
  "review.md",
  "core/shared/review-simplify.md",
  "core/shared/commit.md",
  "errors.md",
  "setup.md"
)
$sharedFiles = @(
  "core/shared/review-simplify.md",
  "core/shared/e2e-verify.md",
  "core/shared/commit.md"
)
$symlinkTargets = @{
  "review-simplify.md" = "core/shared/review-simplify.md"
  "commit.md" = "core/shared/commit.md"
}

function Test-Command([string]$Name) {
  return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

Write-Host "=========================================="
Write-Host "  doit-skill Doctor (PowerShell)"
Write-Host "  Skills dir: $SkillDir"
Write-Host "  Platform: $([System.Environment]::OSVersion.VersionString)"
Write-Host "=========================================="
Write-Host ""

# Step 1: Check doit skill installation
Write-Host "[1/3] Checking doit skill installation..."
$doitPath = Join-Path $SkillDir "doit"
if (Test-Path $doitPath) {
  Write-Host "  [OK] doit skill installed" -ForegroundColor Green

  # Check core files
  $missing = @()
  foreach ($file in $coreFiles) {
    $filePath = Join-Path $doitPath $file
    if (-not (Test-Path $filePath)) {
      $missing += $file
    }
  }

  if ($missing.Count -eq 0) {
    Write-Host "  [OK] Core files present" -ForegroundColor Green
  } else {
    Write-Host "  [FAIL] Missing core files: $($missing -join ', ')" -ForegroundColor Red
  }

  # Check shared phases
  Write-Host "  Checking shared phases..."
  foreach ($sf in $sharedFiles) {
    $sfPath = Join-Path $doitPath $sf
    if (Test-Path $sfPath) {
      Write-Host "  [OK] $sf present" -ForegroundColor Green
    } else {
      Write-Host "  [FAIL] $sf missing" -ForegroundColor Red
    }
  }

  # Check symlinks (Windows: may be symlinks, hard links, or regular files)
  foreach ($lnk in $symlinkTargets.Keys) {
    $target = $symlinkTargets[$lnk]
    $lnkPath = Join-Path $doitPath $lnk

    if (Test-Path $lnkPath) {
      $item = Get-Item $lnkPath
      if ($item.Target) {
        # It's a symlink
        Write-Host "  [OK] $lnk -> $($item.Target) (symlink OK)" -ForegroundColor Green
      } elseif ($item.LinkType) {
        Write-Host "  [OK] $lnk -> $($item.LinkType) OK" -ForegroundColor Green
      } else {
        # Regular file (fallback on non-admin Windows)
        Write-Host "  [OK] $lnk exists (regular file - Windows fallback)" -ForegroundColor Yellow
      }
    } else {
      Write-Host "  [WARN] $lnk not found" -ForegroundColor Yellow
    }
  }
} else {
  Write-Host "  [FAIL] doit skill not installed" -ForegroundColor Red
}
Write-Host ""

# Step 2: Check bundled skills
Write-Host "[2/3] Checking bundled skills..."
foreach ($skill in $bundledSkills) {
  $skillPath = Join-Path $SkillDir $skill
  if (Test-Path $skillPath) {
    Write-Host "  [OK] $skill installed" -ForegroundColor Green
  } else {
    Write-Host "  [FAIL] $skill not installed" -ForegroundColor Red
  }
}
Write-Host ""

# Step 3: Check external tools
Write-Host "[3/3] Checking external tools..."

$pluginsDir = "$HOME/.claude/plugins"

# context-mode
if (Test-Command ctx) {
  Write-Host "  [OK] context-mode installed (CLI)" -ForegroundColor Green
} elseif (Test-Path $pluginsDir) {
  $hasCtx = Get-ChildItem -Path $pluginsDir -Recurse -Filter "*context-mode*" -ErrorAction SilentlyContinue
  if ($hasCtx) {
    Write-Host "  [OK] context-mode installed (plugin)" -ForegroundColor Green
  } else {
    Write-Host "  [INFO] context-mode not installed (recommended)" -ForegroundColor Yellow
    Write-Host "     Install: claude plugin install context-mode@context-mode"
  }
} else {
  Write-Host "  [INFO] context-mode not installed (recommended)" -ForegroundColor Yellow
  Write-Host "     Install: claude plugin install context-mode@context-mode"
}

# rtk
if (Test-Command rtk) {
  Write-Host "  [OK] rtk installed" -ForegroundColor Green
} else {
  Write-Host "  [INFO] rtk not installed (recommended)" -ForegroundColor Yellow
  Write-Host "     Install: cargo install rtk"
}

# uv
if (Test-Command uv) {
  Write-Host "  [OK] uv installed" -ForegroundColor Green
} else {
  Write-Host "  [INFO] uv not installed (recommended)" -ForegroundColor Yellow
  Write-Host "     Install: curl -LsSf https://astral.sh/uv/install.sh | sh"
}

# rust
if (Test-Command cargo) {
  Write-Host "  [OK] rust/cargo installed" -ForegroundColor Green
} else {
  Write-Host "  [INFO] rust not installed (required for rtk)" -ForegroundColor Yellow
  Write-Host "     Install: winget install Rust-lang.Rustup"
}

# tavily
$tavilyOk = $false
try {
  $mcpList = claude mcp list 2>$null
  if ($mcpList -match 'tavily') { $tavilyOk = $true }
} catch { }

$claudeSettings = "$HOME/.claude/settings.json"
if ((Test-Path $claudeSettings) -and (Get-Content $claudeSettings -Raw) -match 'tavily') {
  $tavilyOk = $true
}

if ($tavilyOk) {
  Write-Host "  [OK] tavily configured (MCP)" -ForegroundColor Green
} else {
  Write-Host "  [INFO] tavily not configured (optional)" -ForegroundColor Yellow
  Write-Host "     Configure: claude mcp add tavily --transport http --env TAVILY_API_KEY=%TAVILY_API_KEY% 'https://api.tavily.com/v1/mcp'"
}

# caveman
$cavemanOk = $false
$cavemanSkill = Join-Path $SkillDir "caveman"
if (Test-Path $cavemanSkill) { $cavemanOk = $true }
elseif (Test-Path $pluginsDir) {
  $hasCaveman = Get-ChildItem -Path $pluginsDir -Recurse -Filter "*caveman*" -ErrorAction SilentlyContinue
  if ($hasCaveman) { $cavemanOk = $true }
}
elseif ((Test-Path "$HOME/.claude/hooks/caveman.sh") -or (Test-Path "$HOME/.claude/hooks/caveman-hook.sh")) {
  $cavemanOk = $true
}

if ($cavemanOk) {
  Write-Host "  [OK] caveman installed" -ForegroundColor Green
} else {
  Write-Host "  [INFO] caveman not installed (recommended)" -ForegroundColor Yellow
  Write-Host "     Install: claude plugin install caveman@caveman"
}

# code-review
$reviewOk = $false
$reviewSkill = Join-Path $SkillDir "code-review"
if (Test-Path $reviewSkill) { $reviewOk = $true }
elseif (Test-Path $pluginsDir) {
  $hasReview = Get-ChildItem -Path $pluginsDir -Recurse -Filter "*code-review*" -ErrorAction SilentlyContinue
  if ($hasReview) { $reviewOk = $true }
}

if ($reviewOk) {
  Write-Host "  [OK] code-review installed" -ForegroundColor Green
} else {
  Write-Host "  [INFO] code-review not installed (recommended)" -ForegroundColor Yellow
  Write-Host "     Install: claude plugin install code-review"
}

# mempalace
$mpOk = $false
if (Test-Path $pluginsDir) {
  $hasMP = Get-ChildItem -Path $pluginsDir -Recurse -Filter "*mempalace*" -ErrorAction SilentlyContinue
  if ($hasMP) { $mpOk = $true }
}

if ($mpOk) {
  Write-Host "  [OK] mempalace installed (plugin)" -ForegroundColor Green
} else {
  Write-Host "  [INFO] mempalace plugin not installed (recommended)" -ForegroundColor Yellow
  Write-Host "     Install: claude plugin install --scope user mempalace"
}

if (Test-Command mempalace) {
  Write-Host "  [OK] mempalace CLI installed" -ForegroundColor Green
} else {
  Write-Host "  [INFO] mempalace CLI not installed" -ForegroundColor Yellow
  Write-Host "     Install: uv tool install mempalace"
}

if (Test-Path ".mempalace") {
  Write-Host "  [OK] mempalace initialized" -ForegroundColor Green
} else {
  Write-Host "  [INFO] mempalace not initialized" -ForegroundColor Yellow
  Write-Host "     Initialize: mempalace init . --yes"
}

# headroom
if (Test-Command headroom) {
  Write-Host "  [OK] headroom installed" -ForegroundColor Green
} else {
  Write-Host "  [INFO] headroom not installed (recommended)" -ForegroundColor Yellow
  Write-Host "     Install: uv tool install 'headroom-ai[mcp,proxy]'"
}

try {
  $mcpList = claude mcp list 2>$null
  if ($mcpList -match 'headroom') {
    Write-Host "  [OK] headroom MCP configured" -ForegroundColor Green
  } else {
    Write-Host "  [INFO] headroom MCP not configured" -ForegroundColor Yellow
    Write-Host "     Configure: headroom mcp install"
  }
} catch { }

# lean-ctx
if (Test-Command lean-ctx) {
  Write-Host "  [OK] lean-ctx installed" -ForegroundColor Green
} else {
  Write-Host "  [INFO] lean-ctx not installed (recommended)" -ForegroundColor Yellow
  Write-Host "     Install: curl -fsSL https://leanctx.com/install.sh | sh"
}

if (Test-Path ".claude/rules/lean-ctx.md") {
  Write-Host "  [OK] lean-ctx rules configured (project-local)" -ForegroundColor Green
} elseif (Test-Path "$HOME/.claude/rules/lean-ctx.md") {
  Write-Host "  [OK] lean-ctx rules configured (global)" -ForegroundColor Green
} else {
  Write-Host "  [INFO] lean-ctx rules not configured" -ForegroundColor Yellow
  Write-Host "     Configure: lean-ctx onboard (auto-detected)"
}

# codegraph
if (Test-Command codegraph) {
  Write-Host "  [OK] codegraph installed" -ForegroundColor Green
} else {
  Write-Host "  [INFO] codegraph not installed (recommended)" -ForegroundColor Yellow
  Write-Host "     Install: npm i -g @colbymchenry/codegraph"
}

if (Test-Path ".codegraph") {
  Write-Host "  [OK] codegraph index initialized" -ForegroundColor Green
} else {
  Write-Host "  [INFO] codegraph index not initialized" -ForegroundColor Yellow
  Write-Host "     Initialize: codegraph init -i"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "  [OK] doit-skill Doctor complete!" -ForegroundColor Green
Write-Host "=========================================="
