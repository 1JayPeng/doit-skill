#!/bin/bash
# doit-skill one-line installer
# Usage: curl -fsSL https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh | bash
#
# Installs doit-skill and all dependencies.
# Supports:
#   --skip-optional    Skip optional skills and external tools

set -e

# Configuration
SKILL_DIR="$HOME/.claude/skills"
REPO_URL="https://github.com/1JayPeng/doit-skill"
DRY_RUN=false
SKIP_OPTIONAL=false

# Parse arguments
for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=true ;;
    --skip-optional) SKIP_OPTIONAL=true ;;
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

# Handle dry-run
if [ "$DRY_RUN" = true ]; then
  echo_info "Dry run — showing what would be installed:"
  echo ""
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
    echo "  Built-in Claude Code skills (no install needed):"
    echo "    • code-review    (code quality review)"
    echo "    • security-review (OWASP security audit)"
    echo "    • verify          (behavior verification)"
    echo "    • caveman         (token-compact mode)"
    echo "    • find-skills     (discover skills)"
    echo "    • write-a-skill   (create new skills)"
    echo ""
    echo "  External tools (installed by default):"
    echo "    • context-mode     (/plugin marketplace add mksglu/context-mode)"
    echo "    • rtk              (curl install script)"
    echo "    • uv               (pip install uv)"
    echo "    • tokensave        (cargo install tokensave)"
  fi
  echo ""
  echo "=========================================="
  echo_info "Dry run complete"
  exit 0
fi

# Clone repository to temp directory
TEMP_DIR=$(mktemp -d)
DOIT_DIR="$TEMP_DIR/doit-skill"

echo_info "Cloning doit-skill repository..."
if ! git clone --depth 1 "$REPO_URL" "$DOIT_DIR" 2>/dev/null; then
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
DOIT_DST="$SKILL_DIR/doit"
if [ -d "$DOIT_DST" ]; then
  echo_success "doit already installed at $DOIT_DST"
else
  mkdir -p "$SKILL_DIR"
  # Use rsync to preserve symlinks, or cp -a as fallback
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --exclude='.git' --exclude='.tokensave' --exclude='.claude/skills' "$DOIT_DIR/" "$DOIT_DST/"
  else
    cp -a "$DOIT_DIR" "$DOIT_DST"
    rm -rf "$DOIT_DST/.git" "$DOIT_DST/.tokensave" "$DOIT_DST/.claude/skills"
  fi
  echo_success "doit installed"
fi

# Check symlinks are preserved
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
    echo_success "$skill_name already installed at $skill_path"
    return 0
  fi

  # Check if skill is in doit-skill skills/ directory
  if [ -d "$DOIT_DIR/skills/$skill_name" ]; then
    cp -r "$DOIT_DIR/skills/$skill_name" "$skill_path"
    echo_success "$skill_name installed"
    return 0
  fi

  echo_error "$skill_name not found in repository"
  return 1
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

# Built-in Claude Code skills — already available, no installation needed
  BUILTIN_SKILLS=("code-review" "security-review" "verify" "caveman" "find-skills" "write-a-skill")
  for skill in "${BUILTIN_SKILLS[@]}"; do
    if [ -d "$SKILL_DIR/$skill" ]; then
      echo_success "$skill already installed (user custom)"
    else
      echo_info "$skill is a built-in Claude Code skill (no install needed)"
    fi
  done
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

# Context-Mode (Claude Code plugin — cannot auto-install via curl)
  echo_info "context-mode is a Claude Code plugin"
  echo_warn "Install manually: /plugin marketplace add mksglu/context-mode"
  echo "  /plugin install context-mode@context-mode"

  # RTK
  if command -v rtk >/dev/null 2>&1; then
    echo_success "rtk already installed"
  else
    echo_info "Installing rtk..."
    curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh 2>/dev/null | sh 2>/dev/null || echo_warn "Failed to install rtk"
    if command -v rtk >/dev/null 2>&1; then
      echo_info "Initializing rtk for Claude Code..."
      rtk init -g 2>/dev/null || true
    fi
  fi

  # UV
  if command -v uv >/dev/null 2>&1; then
    echo_success "uv already installed"
  else
    echo_info "Installing uv..."
    pip install uv 2>/dev/null || pip3 install uv 2>/dev/null || echo_warn "Failed to install uv"
  fi

  # TokenSave
  if command -v tokensave >/dev/null 2>&1; then
    echo_success "tokensave already installed"
  else
    echo_info "Installing tokensave..."
    if command -v cargo >/dev/null 2>&1; then
      cargo install tokensave 2>/dev/null || echo_warn "Failed to install tokensave via cargo"
      if command -v tokensave >/dev/null 2>&1; then
        echo_info "Configuring tokensave for Claude Code..."
        tokensave install --agent claude 2>/dev/null || true
      fi
    else
      echo_warn "cargo not found — tokensave requires Rust. Install via: cargo install tokensave"
    fi
  fi
fi

# Step 4: Run doctor before cleanup
echo "=========================================="
echo "  Step 4: Running dependency check"
echo "=========================================="
echo ""

if [ -f "$DOIT_DIR/scripts/doctor.sh" ]; then
  bash "$DOIT_DIR/scripts/doctor.sh"
else
  echo_warn "doctor.sh not found, skipping dependency check"
fi

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "=========================================="
echo "  ✅ doit-skill installation complete!"
echo "=========================================="
echo ""
echo "  To update: re-run this curl command (downloads latest and installs)"
echo "  To check dependencies: ./scripts/doctor.sh"
echo ""
