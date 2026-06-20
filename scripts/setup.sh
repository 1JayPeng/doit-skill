#!/bin/bash
# doit-skill one-line installer
# Usage: curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh | bash
#
# Installs doit-skill and all dependencies.
# Supports:
#   --agent <type>     Target AI coding CLI: claude|opencode|codex|oh-my-pi|mimo|auto (default: auto)
#   --skip-optional    Skip optional skills and external tools
#   --skip-updates     Skip updating already-installed tools

# No set -e: we handle errors explicitly. set -e + 2>/dev/null = silent death.
trap 'echo_error "Installation interrupted by user. Partial install may be in place." && exit 130' INT

# Configuration
# Detect target AI coding CLI
detect_agent() {
  local agent="$1"
  if [ "$agent" = "auto" ]; then
    command -v claude >/dev/null 2>&1 && echo "claude" && return
    command -v opencode >/dev/null 2>&1 && echo "opencode" && return
    command -v codex >/dev/null 2>&1 && echo "codex" && return
    # Default to claude if no specific agent detected
    echo "claude"
    return
  fi
  echo "$agent"
}

AGENT_TYPE="${AGENT:-auto}"
AGENT_TYPE=$(detect_agent "$AGENT_TYPE")
export AGENT_TYPE

# Set agent-specific paths (applied at top-level; --agent overrides below)
_set_agent_paths() {
  case "$1" in
    claude)
      SKILL_DIR=".claude/skills"
      GLOBAL_SKILL_DIR="$HOME/.claude/skills"
      MAIN_INSTRUCTIONS="CLAUDE.md"
      MCP_CONFIG_FILE="$HOME/.claude.json"
      ;;
    opencode)
      SKILL_DIR=".opencode/skills"
      GLOBAL_SKILL_DIR="$HOME/.config/opencode/skills"
      MAIN_INSTRUCTIONS="AGENTS.md"
      MCP_CONFIG_FILE="$HOME/.config/opencode/opencode.json"
      ;;
    codex)
      SKILL_DIR=".agents/skills"
      GLOBAL_SKILL_DIR="$HOME/.codex/skills"
      MAIN_INSTRUCTIONS="AGENTS.md"
      MCP_CONFIG_FILE="$HOME/.codex/config.toml"
      ;;
    oh-my-pi)
      SKILL_DIR=".omp/skills"
      GLOBAL_SKILL_DIR="$HOME/.config/omp/skills"
      MAIN_INSTRUCTIONS="AGENTS.md"
      MCP_CONFIG_FILE="$HOME/.config/omp/mcp.json"
      ;;
    mimo)
      SKILL_DIR=".mimo/skills"
      GLOBAL_SKILL_DIR="$HOME/.config/mimo/skills"
      MAIN_INSTRUCTIONS="AGENTS.md"
      MCP_CONFIG_FILE="$HOME/.config/mimo/settings.json"
      ;;
    *)
      SKILL_DIR=".ai/skills"
      GLOBAL_SKILL_DIR="$HOME/.ai/skills"
      MAIN_INSTRUCTIONS="AGENTS.md"
      MCP_CONFIG_FILE="$HOME/.ai/mcp.json"
      ;;
  esac
}
_set_agent_paths "$AGENT_TYPE"
GH_PROXY="https://v6.gh-proxy.org"
REPO_URL="${GH_PROXY}/https://github.com/1JayPeng/doit-skill"

# This is required for tools (npx skills, claude plugin install, etc.) that
DRY_RUN=false
SKIP_OPTIONAL=false
SKIP_UPDATES=false
SKIP_INITS=false
INSTALL_GLOBAL=false
UPDATED_FILES=()
INSTALL_CACHE="$HOME/.doit/install-cache.json"

# Hash function: portable across Linux/macOS
file_hash() {
  if command -v md5sum >/dev/null 2>&1; then
    md5sum "$1" 2>/dev/null | cut -d' ' -f1
  elif command -v md5 >/dev/null 2>&1; then
    md5 -q "$1" 2>/dev/null
  else
    sha256sum "$1" 2>/dev/null | cut -d' ' -f1
  fi
}

# Spinner: runs a command with animated progress + real-time output to terminal.
# Usage: spin <timeout_s> "<label>" <command...>
# Spinner animates on stderr; command output streams to stdout in real-time.
# Optional trailing --pty flag: use real PTY (script -qc) instead of bash -c.
# Default: no PTY — avoids interactive prompts from remote installers (caveload).
# Only use --pty when the command requires a PTY for non-stdin reasons.
spin() {
  local use_pty=false
  [ "${!#}" = "--pty" ] && use_pty=true && set -- "${@:1:$#-1}"

  local timeout_s="${1:-120}"
  local label="$2"
  shift 2

  # Print header
  echo -e "${BLUE}[⏳]${NC} ${label}..."
  local cmd_str="$*"
  local truncated="${cmd_str:0:120}"
  [ ${#cmd_str} -gt 120 ] && truncated+="..."
  echo -e "     \$ ${truncated}"
  echo ""

  local start_s=$SECONDS
  local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
  local fi=0
  local spin_pid=""

  # Background spinner on stderr (killed after command, don't override main INT trap)
  (
    trap 'exit 0' TERM INT
    while true; do
      printf "\r ${frames[$fi]} running..." >&2
      fi=$(( (fi + 1) % ${#frames[@]} ))
      sleep 0.5
    done
  ) &
  spin_pid=$!

  # Run command — output streams directly to terminal in real-time
  #
  # Default: bash -c < /dev/null — no PTY, no interactive prompts.
  # With --pty: script -qc /dev/null < /dev/null — real PTY for CLIs that need it.
  local exit_code=0
  if [ "$use_pty" = true ] && command -v script >/dev/null 2>&1; then
    if command -v timeout >/dev/null 2>&1; then
      timeout "$timeout_s" script -qc "$cmd_str" /dev/null < /dev/null
    elif command -v gtimeout >/dev/null 2>&1; then
      gtimeout "$timeout_s" script -qc "$cmd_str" /dev/null < /dev/null
    else
      script -qc "$cmd_str" /dev/null < /dev/null
    fi
  else
    if command -v timeout >/dev/null 2>&1; then
      timeout "$timeout_s" bash -c "$cmd_str" < /dev/null
    elif command -v gtimeout >/dev/null 2>&1; then
      gtimeout "$timeout_s" bash -c "$cmd_str" < /dev/null
    else
      bash -c "$cmd_str" < /dev/null
    fi
  fi
  exit_code=$?

  # Stop spinner (main script's INT trap remains intact)
  kill $spin_pid 2>/dev/null
  wait $spin_pid 2>/dev/null
  echo "" >&2

  local elapsed=$(( SECONDS - start_s ))
  local min=$(( elapsed / 60 ))
  local sec=$(( elapsed % 60 ))
  local time_str
  if [ "$min" -gt 0 ]; then
    time_str="${min}m ${sec}s"
  else
    time_str="${sec}s"
  fi

  if [ $exit_code -eq 0 ]; then
    echo -e "${GREEN}[✓]${NC} ${label} completed (${time_str})"
  elif [ $exit_code -eq 124 ]; then
    echo -e "${YELLOW}[!]${NC} ${label} timed out after ${timeout_s}s (ran ${time_str})"
  else
    echo -e "${YELLOW}[!]${NC} ${label} failed (exit $exit_code, ${time_str})"
  fi

  return $exit_code
}

# Create a hash snapshot of a directory: "hash relative_path" per file
make_snapshot() {
  local dir="$1"
  local output="$2"
  while IFS= read -r f; do
    local full="$dir/$f"
    if [ -f "$full" ] && [ ! -L "$full" ]; then
      echo "$(file_hash "$full") $f"
    else
      echo "SYMLINK $f"
    fi
  done < <(find "$dir" \( -type f -o -type l \) \
    \! -path "$dir/.git/*" \
    \! -path "$dir/.tokensave/*" \
    \! -path "$dir/.claude/skills/*" \
    | sed "s|$dir/||" | sort) > "$output"
}

# Compare two hash snapshots, append changed files to UPDATED_FILES
collect_changes() {
  local before_snap="$1"
  local after_snap="$2"

  # Extract paths from hash lines (field 2+)
  local before_paths after_paths
  before_paths=$(mktemp)
  after_paths=$(mktemp)
  cut -d' ' -f2- "$before_snap" > "$before_paths"
  cut -d' ' -f2- "$after_snap" > "$after_paths"

  # Find new files
  while IFS= read -r f; do
    [ -n "$f" ] && UPDATED_FILES+=("$f (new)")
  done < <(comm -13 "$before_paths" "$after_paths")

  # Find deleted files
  while IFS= read -r f; do
    [ -n "$f" ] && UPDATED_FILES+=("$f (removed)")
  done < <(comm -23 "$before_paths" "$after_paths")

  # Find modified files (same path, different hash)
  while IFS= read -r f; do
    local h1 h2
    h1=$(grep " $f$" "$before_snap" | cut -d' ' -f1)
    h2=$(grep " $f$" "$after_snap" | cut -d' ' -f1)
    if [ "$h1" != "SYMLINK" ] && [ "$h2" != "SYMLINK" ] && [ "$h1" != "$h2" ]; then
      UPDATED_FILES+=("$f (modified)")
    fi
  done < <(comm -12 "$before_paths" "$after_paths")

  rm -f "$before_paths" "$after_paths"
}

# Check if a tool was recently installed (<24h) and still works -> skip update
should_skip_update() {
  local tool="$1"
  [ ! -f "$INSTALL_CACHE" ] && return 1
  local ts
  ts=$(python3 -c "
import json
try:
    with open('${INSTALL_CACHE}') as f:
        d = json.load(f)
    print(int(d.get('${tool}', {}).get('installed_at', 0)))
except: print(0)
" 2>/dev/null)
  local now=$(date +%s)
  local age=$(( now - ts ))
  [ "$age" -lt 86400 ] && command -v "$tool" >/dev/null 2>&1 && return 0
  return 1
}

# Record successful tool installation in cache
record_install() {
  mkdir -p "$HOME/.doit"
  python3 -c "
import json, time
path = '${INSTALL_CACHE}'
try:
    with open(path) as f: d = json.load(f)
except: d = {}
d['${1}'] = {'installed_at': time.time()}
with open(path, 'w') as f: json.dump(d, f, indent=2)
" 2>/dev/null || true
}

# Parse arguments
i=1
while [ $i -le $# ]; do
  arg="${!i}"
  case $arg in
    --dry-run) DRY_RUN=true ;;
    --skip-optional) SKIP_OPTIONAL=true ;;
    --skip-updates) SKIP_UPDATES=true ;;
    --skip-inits) SKIP_INITS=true ;;
    --global) INSTALL_GLOBAL=true ;;
    --agent)
      i=$((i + 1))
      AGENT_TYPE="${!i:-auto}"
      AGENT_TYPE=$(detect_agent "$AGENT_TYPE")
      export AGENT_TYPE
      _set_agent_paths "$AGENT_TYPE"
      ;;
    *) ;;
  esac
  i=$((i + 1))
done

# --global applies after --agent resolves paths
if [ "$INSTALL_GLOBAL" = true ]; then
  SKILL_DIR="$GLOBAL_SKILL_DIR"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
echo_success() { echo -e "${GREEN}[✓]${NC} $1"; }
echo_skip()    { echo -e "${CYAN}[~]${NC} $1"; }
echo_warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
echo_error()   { echo -e "${RED}[✗]${NC} $1"; }

echo "=========================================="
echo "  doit-skill Installer"
echo "  $(date)"
echo "  Agent: $AGENT_TYPE"
echo "=========================================="
echo ""

# Show hint if re-installing (tools already present)
if command -v rtk >/dev/null 2>&1; then
  echo "  [HINT] Some tools already installed. Use --skip-updates to speed up re-install."
  echo ""
fi

# Ask about doc-capture (interactive, skip if piped/non-tty)
DOC_CAPTURE="true"
if [ -t 0 ] && [ -t 1 ]; then
  read -r -p "Enable doc-capture (persist reference docs in .doit/docs/)? [Y/n] " answer
  case "${answer:-Y}" in
    [yY][eE][sS]|[yY]) DOC_CAPTURE="true" ;;
    *) DOC_CAPTURE="false" ;;
  esac
fi

# Ask about subagent orchestration (interactive, skip if piped/non-tty)
SUBAGENT_ENABLED="true"
if [ -t 0 ] && [ -t 1 ]; then
  read -r -p "Enable subagent orchestration (parallel, token-intensive)? [Y/n] " answer
  case "${answer:-Y}" in
    [nN][oO]|[nN]) SUBAGENT_ENABLED="false" ;;
    *) SUBAGENT_ENABLED="true" ;;
  esac
fi

# Ask about auto commit (interactive, skip if piped/non-tty)
AUTO_COMMIT="false"
if [ -t 0 ] && [ -t 1 ]; then
  read -r -p "Enable auto commit (skip confirmation before commit/push)? [y/N] " answer
  case "${answer:-N}" in
    [yY][eE][sS]|[yY]) AUTO_COMMIT="true" ;;
    *) AUTO_COMMIT="false" ;;
  esac
fi
# Ask about headroom proxy (interactive, skip if piped/non-tty) — default true
HEADROOM_PROXY="true"
if [ -t 0 ] && [ -t 1 ]; then
  read -r -p "Enable headroom proxy (auto-compress all tool output, 60-95% token savings)? [Y/n] " answer
  case "${answer:-Y}" in
    [nN][oO]|[nN]) HEADROOM_PROXY="false" ;;
    *) HEADROOM_PROXY="true" ;;
  esac
fi

# Show config summary so piped installs know what defaults were used
echo ""
echo "  [CONFIG] doc-capture: $DOC_CAPTURE | subagent: $SUBAGENT_ENABLED | auto-commit: $AUTO_COMMIT | headroom-proxy: $HEADROOM_PROXY"
if [ ! -t 0 ]; then
  echo "  💡 stdin is piped — defaults used above. Re-run interactively to customize."
  echo "     Or edit ~/.doit/config.yaml after install."
fi

# Write ~/.doit/config.yaml from user choices (idempotent — only create if not present)
mkdir -p "$HOME/.doit"
if [ ! -f "$HOME/.doit/config.yaml" ]; then
  cat > "$HOME/.doit/config.yaml" <<CONFIG_EOF
subagent:
  enabled: ${SUBAGENT_ENABLED}
auto_commit:
  enabled: ${AUTO_COMMIT}
doc-capture:
  enabled: ${DOC_CAPTURE}
headroom:
  proxy:
    enabled: ${HEADROOM_PROXY}
    port: 8787
commit:
  branch: branch
CONFIG_EOF
  echo_success "Created ~/.doit/config.yaml"
else
  echo_success "~/.doit/config.yaml already exists (keeping current settings)"
fi

# Tavily API Key: always read .env first (before checking MCP list)
# This ensures .env key is available even when old MCP config already exists
TAVILY_API_KEY="${TAVILY_API_KEY:-}"
TAVILY_CONFIGURED=false
if [ -f .env ] && grep -q 'TAVILY_API_KEY' .env 2>/dev/null; then
  # tail -1: .env may have multiple TAVILY_API_KEY lines (old keys, comments)
  # -> only use the last one. Without tail, grep returns all lines ->
  # bash -c executes each line as a separate command -> "command not found"
  TAVILY_API_KEY=$(grep 'TAVILY_API_KEY' .env | tail -1 | cut -d'=' -f2- | tr -d '"' | tr -d "'" | tr -d '[:space:]')
  TAVILY_CONFIGURED=true
  echo_success "tavily API key found in .env"
elif spin 30 "tavily MCP check" "claude mcp list" 2>/dev/null | grep -q tavily; then
  TAVILY_CONFIGURED=true
  echo_success "tavily MCP already configured"
elif grep -q 'tavily' ~/.claude.json 2>/dev/null; then
  TAVILY_CONFIGURED=true
  echo_success "tavily configured in .claude.json"
elif grep -q 'tavily' ~/.config/opencode/opencode.json 2>/dev/null; then
  TAVILY_CONFIGURED=true
  echo_success "tavily configured in opencode.json"
elif grep -q 'tavily' ~/.codex/config.toml 2>/dev/null; then
  TAVILY_CONFIGURED=true
  echo_success "tavily configured in codex config.toml"
fi

# Ask about Tavily API Key only if not already configured
if [ "$TAVILY_CONFIGURED" != "true" ]; then
  _ask_tavily() {
    if [ -t 0 ] && [ -t 1 ]; then
      read -r -p "Tavily API Key (for web search, or press Enter to skip): " TAVILY_API_KEY
    elif [ -e /dev/tty ]; then
      echo ""
      echo -n "Tavily API Key (for web search, or press Enter to skip): "
      read -r TAVILY_API_KEY < /dev/tty || true
    else
      echo_warn "No TTY available, skipping Tavily API key prompt (set TAVILY_API_KEY env var instead)"
    fi
  }
  _ask_tavily 2>/dev/null
fi

# Install Tavily MCP immediately after API key is obtained.
# This runs BEFORE git clone and all other steps, so Tavily is never
# lost if later steps fail.
#
# IMPORTANT: Write directly to ~/.claude.json via Python. Using `claude mcp add`
# inside spin() → bash -c "$cmd_str" loses shell quoting on the URL, causing
# the API key to leak into stderr and get executed as a command.
if [ -n "$TAVILY_API_KEY" ]; then
  echo_info "Configuring Tavily MCP with your API key..."

  # Determine MCP config file based on agent type
  case "$AGENT_TYPE" in
    claude)   _mcp_config_file="$HOME/.claude.json" ;;
    opencode) _mcp_config_file="$HOME/.config/opencode/opencode.json" ;;
    codex)    _mcp_config_file="$HOME/.codex/config.toml" ;;
    *)        _mcp_config_file="$HOME/.ai/mcp.json" ;;
  esac

  # Remove old tavily entry if exists (JSON config)
  if [ -f "$_mcp_config_file" ] && [[ "$_mcp_config_file" == *.json ]]; then
    PATH_FILE="$_mcp_config_file" python3 -c "
import json, os
path = os.environ['PATH_FILE']
try:
    with open(path) as f:
        d = json.load(f)
    mcp = d.get('mcp', {})
    if 'tavily' in mcp:
        del mcp['tavily']
        with open(path, 'w') as f:
            json.dump(d, f, indent=2)
except: pass
" 2>/dev/null || true
  fi

  # Write tavily config directly via env vars — avoids spin() bash -c quoting
  # AND prevents shell injection from API keys containing quotes/backslashes
  CONFIG_PATH="$_mcp_config_file" TAVILY_KEY="$TAVILY_API_KEY" python3 -c "
import json, os
path = os.environ['CONFIG_PATH']
key = os.environ['TAVILY_KEY']
if path.endswith('.json'):
    try:
        with open(path) as f:
            d = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        d = {}
    if 'mcp' not in d:
        d['mcp'] = {}
    d['mcp']['tavily'] = {
        'transport': 'http',
        'url': f'https://mcp.tavily.com/mcp/?tavilyApiKey={key}'
    }
    with open(path, 'w') as f:
        json.dump(d, f, indent=2)
elif path.endswith('.toml'):
    # For Codex config.toml, append MCP section
    import tomllib
    try:
        with open(path, 'rb') as f:
            d = tomllib.load(f)
    except (FileNotFoundError, Exception):
        d = {}
    mcp = d.get('mcp', {})
    mcp['tavily'] = {
        'transport': 'http',
        'url': f'https://mcp.tavily.com/mcp/?tavilyApiKey={key}'
    }
    d['mcp'] = mcp
    # Write back as TOML
    with open(path, 'w') as f:
        for section, values in d.items():
            if isinstance(values, dict):
                f.write(f'[{section}]\\n')
                for k, v in values.items():
                    if isinstance(v, dict):
                        f.write(f'[{section}.{k}]\\n')
                        for kk, vv in v.items():
                            f.write(f'{kk} = \"{vv}\"\\n')
                    else:
                        f.write(f'{k} = \"{v}\"\\n')
            else:
                f.write(f'{section} = {values}\\n')
" 2>/dev/null

  if [ -f "$_mcp_config_file" ] && grep -q 'tavily' "$_mcp_config_file" 2>/dev/null; then
    echo_success "tavily MCP configured ($_mcp_config_file)"
  else
    echo_warn "Failed to write Tavily MCP config — configure manually for $AGENT_TYPE"
  fi
fi

# Start Headroom Proxy if enabled (before git clone so Tavily + Proxy are ready early)
if [ -f "$HOME/.doit/config.yaml" ]; then
  _hr_proxy=$(grep -A1 'proxy:' "$HOME/.doit/config.yaml" 2>/dev/null | grep 'enabled:' | awk '{print $2}')
  _hr_port=$(grep -A2 'proxy:' "$HOME/.doit/config.yaml" 2>/dev/null | grep 'port:' | awk '{print $2}')
else
  _hr_proxy="false"
  _hr_port="8787"
fi
if [ "$_hr_proxy" = "true" ] && command -v headroom >/dev/null 2>&1; then
  echo_info "Starting headroom proxy on port ${_hr_port:-8787}..."
  headroom proxy --port ${_hr_port:-8787} &
  HEADROOM_PID=$!
  export ANTHROPIC_BASE_URL=http://127.0.0.1:${_hr_port:-8787}
  echo "HEADROOM_PID=$HEADROOM_PID" > /tmp/headroom-proxy.pid
  echo_success "headroom proxy started (PID $HEADROOM_PID)"
  echo_info "All tool outputs now auto-compressed (60-95% token savings)"
fi

# Handle dry-run
if [ "$DRY_RUN" = true ]; then
  echo_info "Dry run — showing what would be installed:"
  echo ""
  echo "  Install location: $SKILL_DIR/"
  echo "  Target agent:    $AGENT_TYPE"
  echo "  Main config:     $MAIN_INSTRUCTIONS"
  echo "  Required skills:"
  echo "    • doit-skill (core)"
  echo "    • grill-me (spec grilling)"
  echo "    • tdd (test-driven development)"
  echo "    • diagnose (bug diagnosis)"
  echo "    • prototype (throwaway prototypes)"
  echo "    • handoff (session handoff)"
  echo "    • improve-codebase-architecture (architecture)"
  echo ""
  if [ "$SKIP_OPTIONAL" = false ]; then
    echo "  External tools (installed by default):"
    echo "    • context-mode     (claude plugin marketplace add mksglu/context-mode)"
    echo "    • rtk              (cargo install rtk)"
    echo "    • uv               (official install script)"
    echo "    • rust               (rustup, Tsinghua mirror)"
    echo "    • tavily           (claude mcp add --transport http tavily ...)"
    echo "    • caveman          (claude plugin + hooks + statusline config)"
echo "    • code-review      (claude plugin install code-review)"
    echo "    • mempalace        (claude plugin install --scope user mempalace)"
    echo "    • headroom         (uv tool install headroom-ai[mcp,proxy])"
    echo "    • lean-ctx         (curl install script)"
    echo "    • codegraph        (npm i -g @colbymchenry/codegraph)"
  fi

  echo "  Options (configurable at install):"
  echo "    • doc-capture    (persist reference docs, default: enabled)"
  echo "    • subagent       (parallel orchestration, default: enabled)"
  echo "    • auto_commit    (skip commit/push confirmation, default: disabled)"
  echo "    • --global       install to ~/.claude/skills/ instead of .claude/skills/"

  echo ""
  echo "=========================================="
  echo_info "Dry run complete"
  exit 0
fi

# Clone repository to temp directory
TEMP_DIR=$(mktemp -d)
DOIT_DIR="$TEMP_DIR/doit-skill"

echo_info "Cloning doit-skill repository..."
if ! git clone --depth 1 "$REPO_URL" "$DOIT_DIR"; then
  echo_error "Failed to clone repository: $REPO_URL"
  echo_error "Check your network connection, or try again later."
  exit 1
fi
echo_success "Repository cloned to $DOIT_DIR"

# Step 1: Install required skills
echo "=========================================="
echo "  Step 1: Installing required skills"
echo "=========================================="
echo ""

# Install doit core skill — preserves symlinks (shared phases)
# For updates: only copies new/changed files + fixes broken symlinks. No rm -rf.
DOIT_DST="$SKILL_DIR/doit"

if [ -d "$DOIT_DST" ]; then
  echo_success "doit already installed at $DOIT_DST — updating..."

  # Snapshot before update for change log
  BEFORE_SNAP=$(mktemp)
  make_snapshot "$DOIT_DST" "$BEFORE_SNAP"

  # Incremental file update (preserves symlinks, copies only new/changed files)
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --exclude='.git' --exclude='.tokensave' --exclude='.claude/skills' --exclude='skills' --exclude='.doit' "$DOIT_DIR/" "$DOIT_DST/"
  else
    # Copy all, then exclude dev-only dirs
    cp -a "$DOIT_DIR/." "$DOIT_DST/"
    rm -rf "$DOIT_DST/.doit"
  fi

  # Snapshot after update, compare
  AFTER_SNAP=$(mktemp)
  make_snapshot "$DOIT_DST" "$AFTER_SNAP"
  collect_changes "$BEFORE_SNAP" "$AFTER_SNAP"
  rm -f "$BEFORE_SNAP" "$AFTER_SNAP"

  # Fix broken symlinks: if symlink target was copied as regular file, replace it
  for lnk in review-simplify.md commit.md; do
    target="shared/$lnk"
    if [ -f "$DOIT_DST/$lnk" ] && [ ! -L "$DOIT_DST/$lnk" ]; then
      rm "$DOIT_DST/$lnk"
      ln -s "$target" "$DOIT_DST/$lnk"
      UPDATED_FILES+=("$lnk (symlink fixed)")
      echo_success "$lnk -> fixed symlink (was regular file)"
    fi
  done

  # Ensure shared/ directory exists with all files
  if [ ! -d "$DOIT_DST/shared" ] && [ -d "$DOIT_DIR/shared" ]; then
    cp -a "$DOIT_DIR/shared" "$DOIT_DST/shared"
    while IFS= read -r f; do
      UPDATED_FILES+=("$f")
    done < <(find "$DOIT_DST/shared" -type f | sed "s|$DOIT_DST/||")
    echo_success "shared/ directory restored"
  fi

  # Clean excluded dirs
  rm -rf "$DOIT_DST/.git" "$DOIT_DST/.tokensave" "$DOIT_DST/.claude/skills" "$DOIT_DST/skills" "$DOIT_DST/.doit"
else
  mkdir -p "$SKILL_DIR"
  cp -a "$DOIT_DIR" "$DOIT_DST"
  rm -rf "$DOIT_DST/.git" "$DOIT_DST/.tokensave" "$DOIT_DST/.claude/skills" "$DOIT_DST/skills" "$DOIT_DST/.doit"
  echo_success "doit installed"
fi

# No .claude-plugin/plugin.json needed — doit is a skill loaded from .claude/skills/doit/
# SKILL.md stays at the root of the doit directory (not in a nested skills/ subdirectory)
# The plugin.json + nested skills/ structure was causing /doit to not be recognized

# Verify symlinks
for lnk in review-simplify.md commit.md; do
  if [ -L "$DOIT_DST/$lnk" ]; then
    echo_success "$lnk -> $(readlink "$DOIT_DST/$lnk") (symlink OK)"
  else
    echo_warn "$lnk is not a symlink — running without shared phase symlinks"
  fi
done

# Check and install each bundled skill
install_skill() {
  local skill_name="$1"
  local skill_path="$SKILL_DIR/$skill_name"

  if [ -d "$skill_path" ]; then
    # Update existing: compare and record changes
    if [ -d "$DOIT_DIR/skills/$skill_name" ]; then
      local before_snap after_snap
      before_snap=$(mktemp)
      after_snap=$(mktemp)
      make_snapshot "$skill_path" "$before_snap"
      rm -rf "$skill_path"
      cp -r "$DOIT_DIR/skills/$skill_name" "$skill_path"
      make_snapshot "$skill_path" "$after_snap"
      collect_changes "$before_snap" "$after_snap"
      rm -f "$before_snap" "$after_snap"
      echo_success "$skill_name updated"
    else
      echo_success "$skill_name already installed at $skill_path"
    fi
  else
    # Check if skill is in doit-skill skills/ directory
    if [ -d "$DOIT_DIR/skills/$skill_name" ]; then
      cp -r "$DOIT_DIR/skills/$skill_name" "$skill_path"
      echo_success "$skill_name installed"
    else
      echo_error "$skill_name not found in repository"
      return 1
    fi
  fi

  # Ensure .claude-plugin/ is copied (cp -r may skip dotfiles on some systems)
  if [ -d "$DOIT_DIR/skills/$skill_name/.claude-plugin" ]; then
    cp -r "$DOIT_DIR/skills/$skill_name/.claude-plugin" "$skill_path/.claude-plugin"
  fi

  echo_success "$skill_name ready (SKILL.md at root)"
  return 0
}

# Install bundled skills
install_skill "grill-me"
install_skill "tdd"
install_skill "diagnose"
install_skill "prototype"
install_skill "handoff"
install_skill "improve-codebase-architecture"

echo ""

# Step 2: Install optional skills
if [ "$SKIP_OPTIONAL" = true ]; then
  echo "=========================================="
  echo "  Step 2: Skipping optional skills (--skip-optional)"
  echo "=========================================="
  echo ""
else
  echo "=========================================="
  echo "  Step 2: Installing optional skills"
  echo "=========================================="
  echo ""

# Skill-Creator (from anthropics/skills) — detect via npx skills list
  if command -v npx >/dev/null 2>&1; then
    _sc_installed=false
    if npx skills list 2>/dev/null | grep -q 'skill-creator'; then
      _sc_installed=true
    fi
    # Fallback: check common install paths
    if [ "$_sc_installed" = false ] && ([ -d "$HOME/.agents/skills/skill-creator" ] || [ -d ".agents/skills/skill-creator" ]); then
      _sc_installed=true
    fi

    if [ "$_sc_installed" = true ]; then
      if [ "$SKIP_UPDATES" = true ]; then
        echo_skip "skill-creator already installed (skipping update)"
      else
        echo_info "Updating skill-creator..."
        npx skills add anthropics/skills@skill-creator -y --non-interactive </dev/null 2>&1 || \
          echo_warn "Failed to update skill-creator (some agents may not support installation — this is non-blocking)"
      fi
    else
      echo_info "Installing skill-creator..."
      npx skills add anthropics/skills@skill-creator -y --non-interactive </dev/null 2>&1 || \
        echo_warn "Failed to install skill-creator (some agents may not support installation — this is non-blocking)"
    fi
  else
    echo_warn "npx not found — skill-creator requires Node.js. Install manually:"
    echo "     npx skills add anthropics/skills@skill-creator"
  fi
fi

# Step 3: Install external tools
if [ "$SKIP_OPTIONAL" = true ]; then
  echo "=========================================="
  echo "  Step 3: Skipping external tools (--skip-optional)"
  echo "=========================================="
  echo ""
else
  echo "=========================================="
  echo "  Step 3: Installing external tools"
  echo "=========================================="
  echo ""

  # Fast-track: all tools installed recently -> skip Step 3
  _skip_step_3=false
  if [ ! -f "$INSTALL_CACHE" ]; then
    _installed_count=0
    for _t in rtk uv cargo lean-ctx codegraph headroom; do
      command -v "$_t" >/dev/null 2>&1 && _installed_count=$(( _installed_count + 1 ))
    done
    grep -rl "context-mode" "$HOME/.claude/plugins/" >/dev/null 2>&1 && _installed_count=$(( _installed_count + 1 ))
    grep -rl "caveman" "$HOME/.claude/plugins/" >/dev/null 2>&1 && _installed_count=$(( _installed_count + 1 ))
    [ "$_installed_count" -ge 9 ] && _skip_step_3=true
  fi

  if [ "$_skip_step_3" = "true" ]; then
    echo_skip "All tools installed — skipping Step 3 (re-run with --skip-updates=false to force)"
    echo ""
  fi

# Context-Mode (Claude Code plugin)
  if [ "$_skip_step_3" = "false" ]; then
  if grep -rl "context-mode" "$HOME/.claude/plugins/" > /dev/null 2>&1; then
    if [ "$SKIP_UPDATES" = true ]; then
      echo_skip "context-mode already installed (skipping update)"
    else
      echo_info "Updating context-mode..."
      spin 60 "context-mode update" claude plugin install context-mode@context-mode --pty || echo_warn "context-mode update failed"
      echo_success "context-mode updated"
    fi
  else
    echo_info "Installing context-mode..."
    spin 120 "context-mode marketplace add" claude plugin marketplace add mksglu/context-mode --pty || echo_warn "Failed to add context-mode marketplace"
    spin 180 "context-mode install" claude plugin install context-mode@context-mode --pty || echo_warn "Failed to install context-mode"
  fi

  # RTK
  # Ensure $HOME/.local/bin is in PATH — rtk installs there, but the install script
  # does NOT modify shell profile. Without this, command -v rtk fails even after
  # successful download, and rtk init -g gets skipped.
  if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    export PATH="$HOME/.local/bin:$PATH"
  fi

  # Persist PATH for future shells (idempotent)
  for _profile in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
    if [ -f "$_profile" ]; then
      grep -q 'export PATH=.*\.local/bin' "$_profile" 2>/dev/null || \
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$_profile"
    fi
  done

  if command -v rtk >/dev/null 2>&1; then
    if [ "$SKIP_UPDATES" = true ]; then
      echo_skip "rtk already installed (skipping update)"
    else
      echo_info "Updating rtk..."
      if command -v cargo >/dev/null 2>&1; then
        spin 120 "rtk update (cargo)" cargo install rtk || echo_warn "Failed to update rtk via cargo"
      fi
      if ! command -v rtk >/dev/null 2>&1; then
        echo_info "Falling back to curl install script..."
        spin 60 "rtk update (curl | sh)" "curl -fsSL ${GH_PROXY}/https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh 2>/dev/null | sh" || echo_warn "Failed to update rtk"
      fi
    fi
  else
    echo_info "Installing rtk..."
    if command -v cargo >/dev/null 2>&1; then
      spin 120 "rtk install (cargo)" cargo install rtk || echo_warn "Failed to install rtk via cargo"
    fi
    if ! command -v rtk >/dev/null 2>&1; then
      echo_info "Falling back to curl install script..."
      spin 60 "rtk install (curl | sh)" "curl -fsSL ${GH_PROXY}/https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh 2>/dev/null | sh" || echo_warn "Failed to install rtk"
    fi
  fi
  if command -v rtk >/dev/null 2>&1; then
    echo_info "Initializing rtk for Claude Code..."
    spin 30 "rtk init" "rtk init -g < /dev/null" 2>/dev/null || true
    echo_success "rtk installed and initialized"
  fi

  # Configure pip mirror (Tsinghua) — needed for uv's pip fallback
  if command -v pip >/dev/null 2>&1; then
    pip config get global.index-url >/dev/null 2>&1 || {
      pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple 2>/dev/null || true
      pip config set install.trusted-host pypi.tuna.tsinghua.edu.cn 2>/dev/null || true
    }
  fi

  # UV
  if command -v uv >/dev/null 2>&1; then
    if [ "$SKIP_UPDATES" = true ]; then
      echo_skip "uv already installed (skipping update)"
    else
      echo_info "Updating uv..."
      spin 120 "uv update" uv self update || echo_warn "Failed to update uv"
    fi
  else
    echo_info "Installing uv (official install script)..."
    if spin 120 "uv install (curl | sh)" "curl -LsSf https://astral.sh/uv/install.sh | sh" 2>&1; then
      # Source uv env for current shell
      [ -f "$HOME/.local/env.txt" ] && source "$HOME/.local/env.txt" 2>/dev/null || true
      export PATH="$HOME/.local/bin:$PATH"
    else
      echo_warn "Official uv install script failed, falling back to pip"
      spin 60 "uv install (pip)" "pip install uv --break-system-packages" 2>&1 || spin 60 "uv install (pip3)" "pip3 install uv --break-system-packages" 2>&1 || echo_warn "Failed to install uv"
    fi
  fi

  # Configure uv default PyPI mirror (Tsinghua)
  if command -v uv >/dev/null 2>&1; then
    mkdir -p "$HOME/.config/uv"
    if ! grep -q "pypi.tuna.tsinghua.edu.cn" "$HOME/.config/uv/uv.toml" 2>/dev/null; then
      cat > "$HOME/.config/uv/uv.toml" <<'UV_EOF'
[[index]]
url = "https://pypi.tuna.tsinghua.edu.cn/simple"
default = true
UV_EOF
      echo_success "uv PyPI mirror configured (Tsinghua)"
    fi
  fi

  # Rust (required by rtk) — always check for updates
  if command -v cargo >/dev/null 2>&1; then
    echo_info "Updating Rust via rustup..."
    spin 120 "rustup update stable" "RUSTUP_DIST_SERVER=https://mirrors.tuna.tsinghua.edu.cn/rustup RUSTUP_UPDATE_ROOT=https://mirrors.tuna.tsinghua.edu.cn/rustup/rustup rustup update stable" 2>&1 || echo_warn "Rust update failed"
    echo_success "Rust updated"
  else
    echo_info "Installing Rust via rustup (Tsinghua mirror)..."
    spin 180 "rustup install (curl | sh)" "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs 2>/dev/null | RUSTUP_DIST_SERVER=https://mirrors.tuna.tsinghua.edu.cn/rustup RUSTUP_UPDATE_ROOT=https://mirrors.tuna.tsinghua.edu.cn/rustup/rustup sh -s -- -y" \
      || echo_warn "Failed to install Rust via rustup"

    # Source cargo env for current shell
    if [ -f "$HOME/.cargo/env" ]; then
      source "$HOME/.cargo/env" 2>/dev/null || true
    fi

    if command -v cargo >/dev/null 2>&1; then
      echo_success "Rust installed"
    fi

    # Configure cargo mirror (USTC) for faster crate downloads
    mkdir -p "$HOME/.cargo"
    cat > "$HOME/.cargo/config.toml" <<'CARGO_EOF'
[source.crates-io]
replace-with = 'ustc'
[source.ustc]
registry = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"
CARGO_EOF
    echo_success "cargo mirror configured (USTC)"

    # Persist rustup mirror in .bashrc for new shells
    grep -q "RUSTUP_DIST_SERVER" "$HOME/.bashrc" 2>/dev/null || {
      echo 'export RUSTUP_DIST_SERVER=https://mirrors.tuna.tsinghua.edu.cn/rustup' >> "$HOME/.bashrc"
      echo 'export RUSTUP_UPDATE_ROOT=https://mirrors.tuna.tsinghua.edu.cn/rustup/rustup' >> "$HOME/.bashrc"
    }
  fi

# Caveman (token-compact mode + statusline) — Claude Code only
  if [ "$AGENT_TYPE" = "claude" ]; then
    if grep -rl "caveman" "$HOME/.claude/plugins/" > /dev/null 2>&1; then
      if [ "$SKIP_UPDATES" = true ]; then
        echo_skip "caveman already installed (skipping update)"
      else
        echo_info "Updating caveman..."
        spin 60 "caveman update" claude plugin install caveman@caveman --pty || echo_warn "caveman update failed"
        echo_success "caveman updated"
      fi
    else
      echo_info "Installing caveman (marketplace -> plugin -> npx fallback)..."
      if spin 120 "caveman marketplace add" claude plugin marketplace add JuliusBrussee/caveman --pty && \
         spin 180 "caveman install" claude plugin install caveman@caveman --pty; then
        echo_success "caveman installed (claude plugin)"
      else
        echo_warn "claude plugin install failed, trying npx installer..."
        if spin 120 "caveman npx installer" curl -fsSL "${GH_PROXY}/https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh" 2>/dev/null | bash -s -- --all; then
          echo_success "caveman installed (npx installer)"
        else
          echo_warn "Failed to install caveman"
        fi
      fi
    fi

    # Caveman statusline hook — install hooks + configure settings.json
    if grep -rl "caveman-statusline" "$HOME/.claude/hooks/" > /dev/null 2>&1; then
      echo_success "caveman statusline hooks already installed"
    else
      echo_info "Installing caveman hooks (statusline)..."
      if spin 120 "caveman hooks install" curl -fsSL "${GH_PROXY}/https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh" 2>/dev/null | bash -s -- --with-hooks --skip-skills; then
        echo_success "caveman statusline hooks installed"
      else
        echo_warn "caveman hook install failed — statusline not configured"
      fi
    fi

    # Configure caveman statusline in settings.json (replace existing if present)
    _claude_settings="$HOME/.claude/settings.json"
    if [ -f "$_claude_settings" ]; then
      _current_sl=$(python3 -c "
import json, sys
try:
    with open('$_claude_settings') as f:
        d = json.load(f)
    sl = d.get('statusLine', {})
    cmd = sl.get('command', '') if isinstance(sl, dict) else str(sl)
    print(cmd)
except: pass
" 2>/dev/null)
      if echo "$_current_sl" | grep -q 'caveman-statusline'; then
        echo_success "caveman statusline already configured in settings.json"
      else
        echo_info "Configuring caveman statusline in settings.json..."
        _hooks_dir="$HOME/.claude/hooks"
        _sl_script="$_hooks_dir/caveman-statusline.sh"
        if [ -f "$_sl_script" ]; then
          python3 -c "
import json
with open('$_claude_settings') as f:
    d = json.load(f)
d['statusLine'] = {'type': 'command', 'command': 'bash \"$_sl_script\"'}
with open('$_claude_settings', 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
" 2>/dev/null && echo_success "caveman statusline configured" || echo_warn "Failed to configure caveman statusline"
        else
          echo_warn "caveman-statusline.sh not found at $_sl_script — install hooks first"
        fi
      fi
    fi
  else
    echo_info "caveman is a Claude Code plugin — skipping for $AGENT_TYPE"
  fi

  # Code Review — Claude Code only
  if [ "$AGENT_TYPE" = "claude" ]; then
    if grep -rl "code-review" "$HOME/.claude/plugins/" > /dev/null 2>&1; then
      if [ "$SKIP_UPDATES" = true ]; then
        echo_skip "code-review already installed (skipping update)"
      else
        echo_info "Updating code-review..."
        spin 60 "code-review update" claude plugin install code-review --pty || echo_warn "code-review update failed"
        echo_success "code-review updated"
      fi
    else
      echo_info "Installing code-review..."
      spin 180 "code-review install" claude plugin install code-review --pty || echo_warn "Failed to install code-review (install manually: claude plugin install code-review)"
    fi
  else
    echo_info "code-review is a Claude Code plugin — skipping for $AGENT_TYPE"
  fi

  # MemPalace — primary memory layer (Claude Code plugin)
  if [ "$AGENT_TYPE" = "claude" ]; then
    if grep -rl "mempalace" "$HOME/.claude/plugins/" > /dev/null 2>&1; then
      if [ "$SKIP_UPDATES" = true ]; then
        echo_skip "mempalace already installed (skipping update)"
      else
        echo_info "Updating mempalace..."
        spin 60 "mempalace update" claude plugin install --scope user mempalace --pty || echo_warn "mempalace update failed"
        echo_success "mempalace updated"
      fi
    else
      echo_info "Installing mempalace..."
      spin 120 "mempalace marketplace add" claude plugin marketplace add MemPalace/mempalace --pty || echo_warn "Failed to add mempalace marketplace"
      spin 180 "mempalace install" claude plugin install --scope user mempalace --pty || echo_warn "Failed to install mempalace (install manually: claude plugin install --scope user mempalace)"
    fi
  else
    echo_info "mempalace Claude Code plugin — skipping for $AGENT_TYPE (MCP server configured separately)"
  fi

  # MemPalace CLI (uv tool)
  if command -v uv >/dev/null 2>&1; then
    if command -v mempalace >/dev/null 2>&1; then
      if [ "$SKIP_UPDATES" = true ]; then
        echo_skip "mempalace CLI already installed (skipping update)"
      else
        echo_info "Updating mempalace CLI..."
        spin 180 "mempalace CLI update" uv tool install mempalace || echo_warn "mempalace CLI update failed"
        echo_success "mempalace CLI updated"
      fi
    else
      echo_info "Installing mempalace CLI..."
      spin 180 "mempalace CLI install" uv tool install mempalace || echo_warn "mempalace CLI install failed"
    fi
  else
    echo_warn "uv not found, skipping mempalace CLI"
  fi

  # MemPalace init (creates HNSW index — per-project, so only if in a project dir)
  if [ -f "mempalace.yaml" ] || [ -d ".mempalace" ]; then
    echo_success "mempalace already initialized"
  else
    echo_info "Initializing mempalace (creating HNSW index — may take 1-2 min)..."
    if command -v mempalace >/dev/null 2>&1; then
      spin 600 "mempalace init (HNSW index)" mempalace init . --yes || echo_warn "Failed to initialize mempalace (run manually: mempalace init . --yes)"
      if [ -f "mempalace.yaml" ]; then
        echo_info "Mining mempalace index..."
        spin 300 "mempalace mine (index mining)" mempalace mine . || echo_warn "mempalace mine timed out (run manually: mempalace mine .)"
      fi
    else
      echo_warn "mempalace CLI not found, skipping init"
    fi
  fi
fi

# Step 3.6: Install lean-ctx (context optimization)
if [ "$SKIP_OPTIONAL" = false ] && [ "${_skip_step_3:-false}" = "false" ]; then
  echo "=========================================="
  echo "  Step 3.6: Installing lean-ctx"
  echo "=========================================="
  echo ""

  if command -v lean-ctx >/dev/null 2>&1; then
    if [ "$SKIP_UPDATES" = true ]; then
      echo_skip "lean-ctx already installed (skipping update)"
    else
      echo_info "Updating lean-ctx..."
      spin 60 "lean-ctx install (curl | sh)" "curl -fsSL https://leanctx.com/install.sh 2>/dev/null | sh" || echo_warn "Failed to update lean-ctx"
    fi
  else
    echo_info "Installing lean-ctx..."
    spin 60 "lean-ctx install (curl | sh)" "curl -fsSL https://leanctx.com/install.sh 2>/dev/null | sh" || echo_warn "Failed to install lean-ctx"
  fi

  if command -v lean-ctx >/dev/null 2>&1; then
    lean-ctx --version 2>&1 || true
    echo_info "Connecting lean-ctx to all AI tools..."
    spin 120 "lean-ctx onboard" lean-ctx onboard || echo_warn "lean-ctx onboard failed"
    source "$HOME/.bashrc" 2>/dev/null || true

    # lean-ctx init --agent X is interactive (prompts for confirmation).
    # Do the project-level config non-interactively:
    #   1. Copy global rules → project-local .claude/rules/lean-ctx.md
    #   2. Create .claude/settings.local.json with lean-ctx hooks
    _lean_ctx_global_rules="$HOME/.claude/rules/lean-ctx.md"
    if [ -f "$_lean_ctx_global_rules" ]; then
      mkdir -p .claude/rules
      cp "$_lean_ctx_global_rules" .claude/rules/lean-ctx.md
      echo_success "lean-ctx project rules configured (.claude/rules/lean-ctx.md)"
    else
      echo_warn "lean-ctx global rules not found — run lean-ctx init --agent claude manually first"
    fi

    if [ -f "$HOME/.claude/settings.local.json" ]; then
      echo_success "lean-ctx project hooks already configured (.claude/settings.local.json)"
    else
      mkdir -p .claude
      cat > .claude/settings.local.json <<'LEANCTX_EOF'
{
  "hooks": {
    "PostToolUse": [{"hooks": [{"command": "lean-ctx hook observe", "type": "command"}], "matcher": ".*"}],
    "PreCompact": [{"hooks": [{"command": "lean-ctx hook observe", "type": "command"}], "matcher": ".*"}],
    "PreToolUse": [
      {"hooks": [{"command": "lean-ctx hook rewrite", "type": "command"}], "matcher": "Bash|bash"},
      {"hooks": [{"command": "lean-ctx hook redirect", "type": "command"}], "matcher": "Read|read|ReadFile|read_file|View|view|Grep|grep|Search|search|ListFiles|list_files|ListDirectory|list_directory"}
    ],
    "Stop": [{"hooks": [{"command": "lean-ctx hook observe", "type": "command"}], "matcher": ".*"}],
    "UserPromptSubmit": [{"hooks": [{"command": "lean-ctx hook observe", "type": "command"}], "matcher": ".*"}]
  }
}
LEANCTX_EOF
      echo_success "lean-ctx project hooks configured (.claude/settings.local.json)"
    fi

    echo_success "lean-ctx installed"
  fi
fi

# Step 3.7: Install headroom (token optimization / CCR proxy compression)
if [ "$SKIP_OPTIONAL" = false ] && [ "${_skip_step_3:-false}" = "false" ]; then
  echo "=========================================="
  echo "  Step 3.7: Installing headroom"
  echo "=========================================="
  echo ""

  # Headroom requires CPython >= 3.10
  _python_ok=false
  for _py in python3.13 python3.12 python3.11 python3.10; do
    if command -v "$_py" >/dev/null 2>&1; then
      _python_ok=true
      break
    fi
  done
  if [ "$_python_ok" = false ] && command -v python3 >/dev/null 2>&1; then
    _py_ver=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)
    if [ -n "$_py_ver" ]; then
      _py_major=${_py_ver%%.*}
      _py_minor=${_py_ver#*.}
      if [ "$_py_major" -ge 3 ] 2>/dev/null && [ "$_py_minor" -ge 10 ] 2>/dev/null; then
        _python_ok=true
      fi
    fi
  fi

  if [ "$_python_ok" = false ]; then
    echo_warn "Python >= 3.10 not found — skipping headroom (requires CPython >= 3.10)"
  else
    # Headroom
    if command -v uv >/dev/null 2>&1; then
      if command -v headroom >/dev/null 2>&1; then
        if [ "$SKIP_UPDATES" = true ]; then
          echo_skip "headroom already installed (skipping update)"
        else
          echo_info "Updating headroom..."
          spin 180 "headroom tool install" uv tool install "headroom-ai[mcp,proxy]" || echo_warn "headroom update failed"
          echo_success "headroom updated"
        fi
      else
        echo_info "Installing headroom..."
        spin 180 "headroom tool install" uv tool install "headroom-ai[mcp,proxy]" || echo_warn "headroom install failed"
      fi
    else
      echo_warn "uv not found — install headroom manually: uv tool install 'headroom-ai[mcp,proxy]'"
    fi

    if command -v headroom >/dev/null 2>&1; then
      if [ "$AGENT_TYPE" = "claude" ]; then
        if spin 30 "headroom MCP verify" "claude mcp list" 2>/dev/null | grep -q headroom; then
          echo_success "headroom MCP already configured"
        else
          echo_info "Configuring headroom MCP..."
          spin 120 "headroom MCP install" headroom mcp install || echo_warn "headroom mcp install timed out"
        fi
      else
        echo_info "headroom MCP — configure manually for $AGENT_TYPE"
      fi
    fi
  fi
fi

# Step 3.8: Install CodeGraph (pre-built code graph index)
if [ "$SKIP_OPTIONAL" = false ] && [ "${_skip_step_3:-false}" = "false" ]; then
  echo "=========================================="
  echo "  Step 3.8: Installing CodeGraph"
  echo "=========================================="
  echo ""

  if command -v codegraph >/dev/null 2>&1; then
    if [ "$SKIP_UPDATES" = true ]; then
      echo_skip "codegraph already installed (skipping update)"
    else
      echo_info "Updating codegraph..."
      spin 60 "codegraph npm install" "npm i -g @colbymchenry/codegraph" 2>&1 || echo_warn "Failed to update codegraph via npm"
    fi
  else
    echo_info "Installing codegraph..."
    spin 60 "codegraph npm install" "npm i -g @colbymchenry/codegraph" 2>&1 || echo_warn "Failed to install codegraph via npm"
  fi

  if command -v codegraph >/dev/null 2>&1; then
    # Install MCP server
    if [ "$AGENT_TYPE" = "claude" ]; then
      if spin 30 "codegraph MCP check" "claude mcp list" 2>/dev/null | grep -qi codegraph; then
        echo_success "codegraph MCP already configured"
      else
        echo_info "Configuring codegraph MCP server..."
        spin 120 "codegraph MCP install" codegraph install --yes || echo_warn "codegraph install timed out (run manually: codegraph install --yes)"
        if spin 30 "codegraph MCP verify" "claude mcp list" 2>/dev/null | grep -qi codegraph; then
          echo_success "codegraph MCP configured"
        else
          echo_warn "codegraph MCP not detected after install — you may need to run: codegraph install --yes"
        fi
      fi
    else
      echo_info "codegraph MCP — configure manually for $AGENT_TYPE"
    fi

    # Initialize project index (skip if already exists)
    if [ -d ".codegraph" ]; then
      echo_success "codegraph index already exists"
    else
      echo_info "Initializing codegraph index..."
      spin 300 "codegraph init (index)" codegraph init -i || echo_warn "codegraph init timed out (run manually: codegraph init -i)"
      if [ -d ".codegraph" ]; then
        echo_success "codegraph index initialized"
      fi
    fi
  fi
  fi  # end _skip_step_3 wrapper
fi

# Step 4: Run doctor before cleanup
echo "=========================================="
echo "  Step 4: Running dependency check"
echo "=========================================="
echo ""

if [ -f "$DOIT_DIR/scripts/doctor.sh" ]; then
  SKILL_DIR="$(cd "$SKILL_DIR" 2>/dev/null && pwd || echo "$SKILL_DIR")" bash "$DOIT_DIR/scripts/doctor.sh"
else
  echo_warn "doctor.sh not found, skipping dependency check"
fi

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "=========================================="
if [ ${#UPDATED_FILES[@]} -gt 0 ]; then
  echo "  ✅ doit-skill updated!"
  echo "=========================================="
  echo ""
  UNIQUE_FILES=$(printf '%s\n' "${UPDATED_FILES[@]}" | sort -u)
  CHANGE_COUNT=$(echo "$UNIQUE_FILES" | wc -l | tr -d ' ')
  echo "  Changed files (${CHANGE_COUNT}):"
  echo "$UNIQUE_FILES" | while IFS= read -r f; do
    echo "    • $f"
  done
  echo ""
else
  echo "  ✅ doit-skill installation complete!"
  echo "=========================================="
  echo ""
fi

# Show current configuration
echo "  [CONFIG] Current doit configuration:"

# Read from existing config or use defaults
_CONFIG_FILE="$HOME/.doit/config.yaml"
if [ -f "$_CONFIG_FILE" ]; then
  _DOC_CAPTURE=$(grep -A1 'doc-capture:' "$_CONFIG_FILE" 2>/dev/null | grep 'enabled:' | awk '{print $2}' || echo "true")
  _SUBAGENT=$(grep -A1 'subagent:' "$_CONFIG_FILE" 2>/dev/null | grep 'enabled:' | awk '{print $2}' || echo "false")
  _AUTO_COMMIT=$(grep -A1 'auto_commit:' "$_CONFIG_FILE" 2>/dev/null | grep 'enabled:' | awk '{print $2}' || echo "false")
  _COMMIT_BRANCH=$(grep -A1 'commit:' "$_CONFIG_FILE" 2>/dev/null | grep 'branch:' | awk '{print $2}' || echo "branch")
else
  _DOC_CAPTURE="$DOC_CAPTURE"
  _SUBAGENT="$SUBAGENT_ENABLED"
  _AUTO_COMMIT="$AUTO_COMMIT"
  _COMMIT_BRANCH="branch"
fi

echo "    doc-capture.enabled: $_DOC_CAPTURE"
echo "    subagent.enabled: $_SUBAGENT"
echo "    auto_commit.enabled: $_AUTO_COMMIT"
echo "    commit.branch: $_COMMIT_BRANCH"
echo ""
echo "  To update: re-run this curl command (downloads latest and installs)"
echo "  To check dependencies: ./scripts/doctor.sh"
echo "  To change config: edit ~/.doit/config.yaml"
echo ""
