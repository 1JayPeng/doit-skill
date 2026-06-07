#!/bin/bash
# doit-skill one-line installer
# Usage: curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh | bash
#
# Installs doit-skill and all dependencies.
# Supports:
#   --skip-optional    Skip optional skills and external tools

# No set -e: we handle errors explicitly. set -e + 2>/dev/null = silent death.
trap 'echo_error "Installation interrupted by user. Partial install may be in place." && exit 130' INT

# Configuration
# Claude Code loads skills from project-local .claude/skills/ (not ~/.claude/skills/)
SKILL_DIR=".claude/skills"
GLOBAL_SKILL_DIR="$HOME/.claude/skills"
REPO_URL="https://v6.gh-proxy.org/https://github.com/1JayPeng/doit-skill"
DRY_RUN=false
SKIP_OPTIONAL=false
INSTALL_GLOBAL=false
UPDATED_FILES=()

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

# Plugin commands can be slow (marketplace lookup + download). Default timeout too short.
# marketplace add: 120s, plugin install: 180s
plugin_cmd() {
  local timeout_s="${1:-120}"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$timeout_s" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$timeout_s" "$@"
  else
    "$@"
  fi
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

# Parse arguments
for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=true ;;
    --skip-optional) SKIP_OPTIONAL=true ;;
    --global) INSTALL_GLOBAL=true; SKILL_DIR="$GLOBAL_SKILL_DIR" ;;
  esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
echo_success() { echo -e "${GREEN}[✓]${NC} $1"; }
echo_warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
echo_error()   { echo -e "${RED}[✗]${NC} $1"; }

echo "=========================================="
echo "  doit-skill Installer"
echo "  $(date)"
echo "=========================================="
echo ""

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

# Check if Tavily is already configured (script doubles as update, don't re-ask)
tavily_already_configured=false
if claude mcp list 2>/dev/null | grep -q tavily; then
  tavily_already_configured=true
  echo_success "tavily MCP already configured"
elif [ -f .env ] && grep -q 'TAVILY_API_KEY' .env 2>/dev/null; then
  tavily_already_configured=true
  echo_success "tavily API key found in .env"
  TAVILY_API_KEY=$(grep 'TAVILY_API_KEY' .env | cut -d'=' -f2- | tr -d '"' | tr -d "'")
elif grep -q 'tavily' ~/.claude/settings.json 2>/dev/null; then
  tavily_already_configured=true
  echo_success "tavily configured in settings.json"
fi

# Ask about Tavily API Key only if not already configured
TAVILY_API_KEY="${TAVILY_API_KEY:-}"
_ask_tavily() {
  if [ -t 0 ] && [ -t 1 ]; then
    read -r -p "Tavily API Key (for web search, or press Enter to skip): " TAVILY_API_KEY
  elif [ -e /dev/tty ]; then
    # Pipe install (curl | bash) — /dev/tty gives real terminal
    echo ""
    echo -n "Tavily API Key (for web search, or press Enter to skip): "
    read -r TAVILY_API_KEY < /dev/tty || true
  else
    # No TTY available — skip silently
    echo_warn "No TTY available, skipping Tavily API key prompt (set TAVILY_API_KEY env var instead)"
  fi
}
if [ "$tavily_already_configured" = false ]; then
  _ask_tavily 2>/dev/null
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
    echo "    • caveman          (claude plugin marketplace add JuliusBrussee/caveman)"
    echo "    • code-review      (claude plugin install code-review)"
    echo "    • mempalace        (claude plugin install --scope user mempalace)"
  fi

  echo "  Options (configurable at install):"
  echo "    • doc-capture    (persist reference docs, default: enabled)"
  echo "    • subagent       (parallel orchestration, default: disabled)"
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
    rsync -a --exclude='.git' --exclude='.tokensave' --exclude='.claude/skills' --exclude='skills' "$DOIT_DIR/" "$DOIT_DST/"
  else
    cp -a "$DOIT_DIR/." "$DOIT_DST/"
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
  rm -rf "$DOIT_DST/.git" "$DOIT_DST/.tokensave" "$DOIT_DST/.claude/skills" "$DOIT_DST/skills"
else
  mkdir -p "$SKILL_DIR"
  cp -a "$DOIT_DIR" "$DOIT_DST"
  rm -rf "$DOIT_DST/.git" "$DOIT_DST/.tokensave" "$DOIT_DST/.claude/skills" "$DOIT_DST/skills"
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

# No built-in skills require checking
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

# Context-Mode (Claude Code plugin)
  if command -v ctx >/dev/null 2>&1; then
    echo_success "context-mode already installed (CLI)"
  elif grep -rl "context-mode" "$HOME/.claude/plugins/" > /dev/null 2>&1; then
    echo_success "context-mode already installed (plugin)"
  else
    echo_info "context-mode is a Claude Code plugin"
    echo_warn "Install manually:"
    echo "     claude plugin marketplace add mksglu/context-mode"
    echo "     claude plugin install context-mode@context-mode"
  fi

# Tavily MCP (web search) - only if API key provided via env or interactive
  if [ -n "$TAVILY_API_KEY" ]; then
    echo_info "Installing Tavily MCP with your API key..."
    claude mcp add --transport http tavily "https://mcp.tavily.com/mcp/?tavilyApiKey=$TAVILY_API_KEY" || echo_warn "Failed to install Tavily MCP (install manually: claude mcp add --transport http tavily https://mcp.tavily.com/mcp/?tavilyApiKey=<your-key>)"
    if claude mcp list 2>/dev/null | grep -q tavily; then
      echo_success "tavily MCP configured"
    else
      echo_warn "tavily MCP not detected after install"
    fi
  fi

  # RTK
  if command -v rtk >/dev/null 2>&1; then
    echo_success "rtk already installed"
  else
    echo_info "Installing rtk..."
    curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh 2>/dev/null | sh || echo_warn "Failed to install rtk"
  fi
  if command -v rtk >/dev/null 2>&1; then
    echo_info "Initializing rtk for Claude Code..."
    rtk init -g 2>/dev/null || true
  fi

  # UV
  if command -v uv >/dev/null 2>&1; then
    echo_success "uv already installed"
  else
    echo_info "Installing uv..."
    pip install uv 2>&1 || pip3 install uv 2>&1 || echo_warn "Failed to install uv"
  fi

  # Rust (required by tokensave)
  if command -v cargo >/dev/null 2>&1; then
    echo_success "rust/cargo already installed"
  else
    echo_info "Installing Rust via rustup (Tsinghua mirror)..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs 2>/dev/null \
      | RUSTUP_DIST_SERVER=https://mirrors.tuna.tsinghua.edu.cn/rustup \
        RUSTUP_UPDATE_ROOT=https://mirrors.tuna.tsinghua.edu.cn/rustup/rustup \
        sh -s -- -y \
      || echo_warn "Failed to install Rust via rustup"

    # Source cargo env for current shell
    if [ -f "$HOME/.cargo/env" ]; then
      source "$HOME/.cargo/env" 2>/dev/null || true
    fi

    if command -v cargo >/dev/null 2>&1; then
      echo_success "Rust installed"

      # Configure cargo mirror (USTC) for faster crate downloads
      echo_info "Configuring cargo mirror (USTC)..."
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
  fi

  # TokenSave
  if command -v tokensave >/dev/null 2>&1; then
    echo_success "tokensave already installed"
  else
    echo_info "Installing tokensave (compiling Rust — may take several minutes)..."
    if command -v cargo >/dev/null 2>&1; then
      cargo install tokensave || echo_warn "Failed to install tokensave via cargo"
      if command -v tokensave >/dev/null 2>&1; then
        echo_info "Configuring tokensave for Claude Code..."
        tokensave install --agent claude || true
      fi
    else
      echo_warn "cargo not found — tokensave requires Rust. Install via: cargo install tokensave"
    fi
  fi

# Caveman (token-compact mode)
  if [ -d "$SKILL_DIR/caveman" ]; then
    echo_success "caveman already installed (project skill)"
  elif [ -d "$HOME/.claude/skills/caveman" ]; then
    echo_success "caveman found in global skills"
  elif grep -rl "caveman" "$HOME/.claude/plugins/" > /dev/null 2>&1; then
    echo_success "caveman already installed (plugin)"
  elif grep -rl "caveman" "$HOME/.claude/hooks/" > /dev/null 2>&1; then
    echo_success "caveman already installed (hooks)"
  else
    echo_info "Installing caveman (marketplace -> plugin -> curl fallback)..."
    if plugin_cmd 120 claude plugin marketplace add JuliusBrussee/caveman && \
       plugin_cmd 180 claude plugin install caveman@caveman; then
      echo_success "caveman installed (claude plugin)"
    else
      echo_warn "claude plugin install failed, trying curl fallback..."
      curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh 2>/dev/null | bash || echo_warn "Failed to install caveman"
    fi
  fi

  # Code Review
  if [ -d "$SKILL_DIR/code-review" ]; then
    echo_success "code-review already installed (project skill)"
  elif [ -d "$HOME/.claude/skills/code-review" ]; then
    echo_success "code-review found in global skills"
  elif grep -rl "code-review" "$HOME/.claude/plugins/" > /dev/null 2>&1; then
    echo_success "code-review already installed (plugin)"
  else
    echo_info "Installing code-review..."
    plugin_cmd 180 claude plugin install code-review || echo_warn "Failed to install code-review (install manually: claude plugin install code-review)"
  fi

  # MemPalace
  if grep -rl "mempalace" "$HOME/.claude/plugins/" > /dev/null 2>&1; then
    echo_success "mempalace already installed (plugin)"
  else
    echo_info "Installing mempalace..."
    plugin_cmd 120 claude plugin marketplace add MemPalace/mempalace || echo_warn "Failed to add mempalace marketplace"
    plugin_cmd 180 claude plugin install --scope user mempalace || echo_warn "Failed to install mempalace (install manually: claude plugin install --scope user mempalace)"
  fi

  # MemPalace CLI (uv tool)
  if command -v mempalace >/dev/null 2>&1; then
    echo_success "mempalace CLI already installed"
  else
    echo_info "Installing mempalace CLI via uv tool..."
    if command -v uv >/dev/null 2>&1; then
      plugin_cmd 180 uv tool install mempalace || echo_warn "Failed to install mempalace CLI (install manually: uv tool install mempalace)"
    else
      echo_warn "uv not found, skipping mempalace CLI install"
    fi
  fi

  # MemPalace init (very slow - creates HNSW index)
  if [ -d ".mempalace" ]; then
    echo_success "mempalace already initialized"
  else
    echo_info "Initializing mempalace (creating HNSW index — may take 1-2 min)..."
    if command -v mempalace >/dev/null 2>&1; then
      plugin_cmd 600 mempalace init . || echo_warn "Failed to initialize mempalace (run manually: mempalace init .)"
    else
      echo_warn "mempalace CLI not found, skipping init"
    fi
  fi
fi

# Step 3.5: Install agentmemory (optional memory layer)
if [ "$SKIP_OPTIONAL" = false ]; then
  echo "=========================================="
  echo "  Step 3.5: Installing agentmemory (optional)"
  echo "=========================================="
  echo ""

  # agentmemory plugin
  if grep -rl "agentmemory" "$HOME/.claude/plugins/" > /dev/null 2>&1; then
    echo_success "agentmemory already installed (plugin)"
  else
    echo_info "Installing agentmemory plugin..."
    plugin_cmd 120 claude plugin marketplace add rohitg00/agentmemory || echo_warn "Failed to add agentmemory marketplace"
    plugin_cmd 180 claude plugin install agentmemory || echo_warn "Failed to install agentmemory (install manually: claude plugin install agentmemory)"
  fi

  # agentmemory server - needs separate terminal
  if curl -s http://localhost:3111/agentmemory/health >/dev/null 2>&1; then
    echo_success "agentmemory server already running"
  else
    echo_info "agentmemory server not running"
    echo_info "To start: npx @agentmemory/agentmemory &"
    echo_info "  (run in a separate terminal, or add '&' to background it)"
    echo_info "  Viewer: http://localhost:3113"
    echo_info "  Health: http://localhost:3111/agentmemory/health"
    echo ""
    echo_info "Starting agentmemory server in background..."
    if command -v npx >/dev/null 2>&1; then
      nohup npx @agentmemory/agentmemory >/dev/null 2>&1 &
      AGENTMEMORY_PID=$!
      echo_info "Started agentmemory server (PID: $AGENTMEMORY_PID)"
      sleep 5
      if curl -s http://localhost:3111/agentmemory/health >/dev/null 2>&1; then
        echo_success "agentmemory server is running"
      else
        echo_warn "agentmemory server may not have started yet. Check manually: curl http://localhost:3111/agentmemory/health"
      fi
    else
      echo_warn "npx not found, skipping agentmemory server start"
    fi
  fi
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
  _COMMIT_BRANCH=$(grep -A1 'commit:' "$_CONFIG_FILE" 2>/dev/null | grep 'branch:' | awk '{print $2}' || echo "branch")
else
  _DOC_CAPTURE="$DOC_CAPTURE"
  _SUBAGENT="$SUBAGENT_ENABLED"
  _COMMIT_BRANCH="branch"
fi

echo "    doc-capture.enabled: $_DOC_CAPTURE"
echo "    subagent.enabled: $_SUBAGENT"
echo "    commit.branch: $_COMMIT_BRANCH"
echo ""
echo "  To update: re-run this curl command (downloads latest and installs)"
echo "  To check dependencies: ./scripts/doctor.sh"
echo "  To change config: edit ~/.doit/config.yaml"
echo ""
