#!/bin/bash
# doit-skill one-line installer
# Usage: curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh | bash
#
# Installs doit-skill and all dependencies.
# Supports:
#   --skip-optional    Skip optional skills and external tools
#   --skip-updates     Skip updating already-installed tools

# No set -e: we handle errors explicitly. set -e + 2>/dev/null = silent death.
trap 'echo_error "Installation interrupted by user. Partial install may be in place." && exit 130' INT

# Configuration
# Claude Code loads skills from project-local .claude/skills/ (not ~/.claude/skills/)
SKILL_DIR=".claude/skills"
GLOBAL_SKILL_DIR="$HOME/.claude/skills"
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
spin() {
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
  # When setup.sh runs via `curl | bash`, stdin is a pipe and stdout may not be
  # a TTY either (inside ssh sessions). Interactive CLIs (claude plugin install)
  # detect non-tty and hang waiting for confirmation.
  #
  # Fix: use `script -qc` to provide a real PTY with /dev/null stdin.
  # Fall back to `bash -c < /dev/null` if script is unavailable.
  local exit_code=0
  if command -v timeout >/dev/null 2>&1; then
    if command -v script >/dev/null 2>&1; then
      timeout "$timeout_s" script -qc "$cmd_str" /dev/null < /dev/null
    else
      timeout "$timeout_s" bash -c "$cmd_str" < /dev/null
    fi
  elif command -v gtimeout >/dev/null 2>&1; then
    if command -v script >/dev/null 2>&1; then
      gtimeout "$timeout_s" script -qc "$cmd_str" /dev/null < /dev/null
    else
      gtimeout "$timeout_s" bash -c "$cmd_str" < /dev/null
    fi
  else
    if command -v script >/dev/null 2>&1; then
      script -qc "$cmd_str" /dev/null < /dev/null
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
for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=true ;;
    --skip-optional) SKIP_OPTIONAL=true ;;
    --skip-updates) SKIP_UPDATES=true ;;
    --skip-inits) SKIP_INITS=true ;;
    --global) INSTALL_GLOBAL=true; SKILL_DIR="$GLOBAL_SKILL_DIR" ;;
  esac
done

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
echo "=========================================="
echo ""

# Show hint if re-installing (tools already present)
if command -v tokensave >/dev/null 2>&1 || command -v rtk >/dev/null 2>&1; then
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
SUBAGENT_ENABLED="false"
if [ -t 0 ] && [ -t 1 ]; then
  read -r -p "Enable subagent orchestration (parallel, token-intensive)? [y/N] " answer
  case "${answer:-N}" in
    [yY][eE][sS]|[yY]) SUBAGENT_ENABLED="true" ;;
    *) SUBAGENT_ENABLED="false" ;;
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
elif grep -q 'tavily' ~/.claude/settings.json 2>/dev/null; then
  TAVILY_CONFIGURED=true
  echo_success "tavily configured in settings.json"
elif grep -q 'tavily' ~/.claude.json 2>/dev/null; then
  TAVILY_CONFIGURED=true
  echo_success "tavily configured in .claude.json"
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

  _claude_json="$HOME/.claude.json"

  # Remove old tavily entry if exists
  if [ -f "$_claude_json" ]; then
    PATH_FILE="$_claude_json" python3 -c "
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
  CONFIG_PATH="$_claude_json" TAVILY_KEY="$TAVILY_API_KEY" python3 -c "
import json, os
path = os.environ['CONFIG_PATH']
key = os.environ['TAVILY_KEY']
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
" 2>/dev/null

  if [ -f "$_claude_json" ] && grep -q 'tavily' "$_claude_json" 2>/dev/null; then
    echo_success "tavily MCP configured"
  else
    echo_warn "Failed to write Tavily MCP config (install manually: claude mcp add --transport http tavily 'https://mcp.tavily.com/mcp/?tavilyApiKey=<your-key>')"
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
    echo "    • rtk              (curl install script)"
    echo "    • uv               (pip install uv)"
    echo "    • rust               (rustup, Tsinghua mirror)"
    echo "    • tokensave        (cargo install tokensave)"
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
  echo "    • subagent       (parallel orchestration, default: disabled)"
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

  # Skills are loaded from .claude/skills/<name>/ with SKILL.md at root
  # No .claude-plugin/plugin.json needed
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

# Skill-Creator (from anthropics/skills)
  if command -v npx >/dev/null 2>&1; then
    if [ -d "$HOME/.agents/skills/skill-creator" ] || [ -d ".agents/skills/skill-creator" ]; then
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
      spin 60 "context-mode update" claude plugin install context-mode@context-mode || echo_warn "context-mode update failed"
      echo_success "context-mode updated"
    fi
  else
    echo_info "Installing context-mode..."
    spin 120 "context-mode marketplace add" claude plugin marketplace add mksglu/context-mode || echo_warn "Failed to add context-mode marketplace"
    spin 180 "context-mode install" claude plugin install context-mode@context-mode || echo_warn "Failed to install context-mode"
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
      spin 60 "rtk install (curl | sh)" "curl -fsSL ${GH_PROXY}/https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh 2>/dev/null | sh" || echo_warn "Failed to update rtk"
    fi
  else
    echo_info "Installing rtk..."
    spin 60 "rtk install (curl | sh)" "curl -fsSL ${GH_PROXY}/https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh 2>/dev/null | sh" || echo_warn "Failed to install rtk"
  fi
  if command -v rtk >/dev/null 2>&1; then
    echo_info "Initializing rtk for Claude Code..."
    spin 30 "rtk init" "rtk init -g < /dev/null" 2>/dev/null || true
    echo_success "rtk installed and initialized"
  fi

  # UV
  if command -v uv >/dev/null 2>&1; then
    if [ "$SKIP_UPDATES" = true ]; then
      echo_skip "uv already installed (skipping update)"
    else
      echo_info "Updating uv..."
      spin 60 "uv update (pip)" "pip install --upgrade uv" 2>&1 || spin 60 "uv update (pip3)" "pip3 install --upgrade uv" 2>&1 || echo_warn "Failed to update uv"
    fi
  else
    echo_info "Installing uv..."
    spin 60 "uv install (pip)" "pip install uv" 2>&1 || spin 60 "uv install (pip3)" "pip3 install uv" 2>&1 || echo_warn "Failed to install uv"
  fi

  # Rust (required by tokensave) — always check for updates
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

  # TokenSave
  if command -v tokensave >/dev/null 2>&1; then
    if [ "$SKIP_UPDATES" = true ] || should_skip_update tokensave; then
      echo_skip "tokensave already installed (skipping update)"
    else
      _ts_installed=$(tokensave --version 2>/dev/null | head -1)
      _ts_latest=$(cargo search tokensave 2>/dev/null | head -1 | grep -oP 'tokensave = "\K[^"]+')
      if [ -n "$_ts_latest" ] && [ "$_ts_installed" != "$_ts_latest" ]; then
        echo_info "Updating tokensave (${_ts_installed} → ${_ts_latest})..."
        spin 600 "tokensave update (cargo install)" cargo install tokensave || echo_warn "Failed to update tokensave"
      else
        echo_success "tokensave up to date"
      fi
    fi
  else
    echo_info "Installing tokensave (compiling Rust — may take several minutes)..."
    if command -v cargo >/dev/null 2>&1; then
      spin 600 "tokensave install (cargo install)" cargo install tokensave || echo_warn "Failed to install tokensave via cargo"
    else
      echo_warn "cargo not found — tokensave requires Rust. Install via: cargo install tokensave"
    fi
  fi
  if command -v tokensave >/dev/null 2>&1; then
    echo_info "Configuring tokensave for Claude Code..."
    tokensave install --agent claude || true
    record_install tokensave
    echo_success "tokensave ready"
  fi

# Caveman (token-compact mode + statusline)
  if grep -rl "caveman" "$HOME/.claude/plugins/" > /dev/null 2>&1; then
    if [ "$SKIP_UPDATES" = true ]; then
      echo_skip "caveman already installed (skipping update)"
    else
      echo_info "Updating caveman..."
      spin 60 "caveman update" claude plugin install caveman@caveman || echo_warn "caveman update failed"
      echo_success "caveman updated"
    fi
  else
    echo_info "Installing caveman (marketplace -> plugin -> npx fallback)..."
    if spin 120 "caveman marketplace add" claude plugin marketplace add JuliusBrussee/caveman && \
       spin 180 "caveman install" claude plugin install caveman@caveman; then
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

  # Code Review
  if grep -rl "code-review" "$HOME/.claude/plugins/" > /dev/null 2>&1; then
    if [ "$SKIP_UPDATES" = true ]; then
      echo_skip "code-review already installed (skipping update)"
    else
      echo_info "Updating code-review..."
      spin 60 "code-review update" claude plugin install code-review || echo_warn "code-review update failed"
      echo_success "code-review updated"
    fi
  else
    echo_info "Installing code-review..."
    spin 180 "code-review install" claude plugin install code-review || echo_warn "Failed to install code-review (install manually: claude plugin install code-review)"
  fi

  # MemPalace — primary memory layer
  if grep -rl "mempalace" "$HOME/.claude/plugins/" > /dev/null 2>&1; then
    if [ "$SKIP_UPDATES" = true ]; then
      echo_skip "mempalace already installed (skipping update)"
    else
      echo_info "Updating mempalace..."
      spin 60 "mempalace update" claude plugin install --scope user mempalace || echo_warn "mempalace update failed"
      echo_success "mempalace updated"
    fi
  else
    echo_info "Installing mempalace..."
    spin 120 "mempalace marketplace add" claude plugin marketplace add MemPalace/mempalace || echo_warn "Failed to add mempalace marketplace"
    spin 180 "mempalace install" claude plugin install --scope user mempalace || echo_warn "Failed to install mempalace (install manually: claude plugin install --scope user mempalace)"
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
    spin 120 "lean-ctx init (Claude agent)" lean-ctx init --agent claude || echo_warn "lean-ctx init --agent claude timed out (may need manual: claude mcp add lean-ctx lean-ctx)"
    echo_success "lean-ctx installed"
  fi

  if [ -f "$HOME/.claude/rules/lean-ctx.md" ]; then
    echo_success "lean-ctx rules configured at ~/.claude/rules/lean-ctx.md"
  else
    echo_warn "lean-ctx rules not found after init — you may need to run: lean-ctx init --agent claude"
  fi
fi

# Step 3.7: Install headroom (token optimization / CCR proxy compression)
if [ "$SKIP_OPTIONAL" = false ] && [ "${_skip_step_3:-false}" = "false" ]; then
  echo "=========================================="
  echo "  Step 3.7: Installing headroom"
  echo "=========================================="
  echo ""

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
    if spin 30 "headroom MCP verify" "claude mcp list" 2>/dev/null | grep -q headroom; then
      echo_success "headroom MCP already configured"
    else
      echo_info "Configuring headroom MCP..."
      spin 120 "headroom MCP install" headroom mcp install || echo_warn "headroom mcp install timed out"
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
