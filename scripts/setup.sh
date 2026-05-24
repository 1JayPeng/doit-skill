#!/bin/bash
# doit-skill one-line installer
# Usage: curl -fsSL https://raw.githubusercontent.com/1JayPeng/doit-skill/main/scripts/setup.sh | bash
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
    echo "  Optional skills (installed by default):"
    echo "    • code-review (code quality review)"
    echo "    • security-review (OWASP security audit)"
    echo "    • verify (behavior verification)"
    echo "    • caveman (token-compact mode)"
    echo "    • find-skills (discover skills)"
    echo "    • write-a-skill (create new skills)"
    echo ""
    echo "  External tools (installed by default):"
    echo "    • context-mode     (npx @anthropic/context-mode)"
    echo "    • rtk              (cargo install rtk)"
    echo "    • uv               (pip install uv)"
    echo "    • codegraph        (npx @anthropic/codegraph init)"
    echo "    • code-review-graph (pip install code-review-graph)"
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
git clone --depth 1 "$REPO_URL" "$DOIT_DIR" >/dev/null 2>&1
echo_success "Repository cloned to $DOIT_DIR"

# Step 1: Install required skills
echo "=========================================="
echo "  Step 1: Installing required skills"
echo "=========================================="
echo ""

# Check and install each required skill
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

# Install required skills
install_skill "doit"
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

  OPTIONAL_SKILLS=("code-review" "security-review" "verify" "caveman" "find-skills" "write-a-skill")
  for skill in "${OPTIONAL_SKILLS[@]}"; do
    if [ -d "$SKILL_DIR/$skill" ]; then
      echo_success "$skill already installed"
    else
      echo_info "Installing $skill..."
      npx --yes skills add $skill 2>/dev/null || echo_warn "Failed to install $skill (you can install manually later)"
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

  # Context-Mode
  if command -v ctx >/dev/null 2>&1; then
    echo_success "context-mode already installed"
  else
    echo_info "Installing context-mode..."
    npx --yes @anthropic/context-mode 2>/dev/null || echo_warn "Failed to install context-mode"
  fi

  # RTK
  if command -v rtk >/dev/null 2>&1; then
    echo_success "rtk already installed"
  else
    echo_info "Installing rtk..."
    cargo install rtk 2>/dev/null || echo_warn "Failed to install rtk"
  fi

  # UV
  if command -v uv >/dev/null 2>&1; then
    echo_success "uv already installed"
  else
    echo_info "Installing uv..."
    pip install uv 2>/dev/null || echo_warn "Failed to install uv"
  fi

  # CodeGraph
  if command -v codegraph >/dev/null 2>&1; then
    echo_success "codegraph already installed"
  else
    echo_info "Installing codegraph..."
    npx --yes @anthropic/codegraph init 2>/dev/null || echo_warn "Failed to install codegraph"
  fi

  # Code-Review-Graph
  if command -v code-review-graph >/dev/null 2>&1; then
    echo_success "code-review-graph already installed"
  else
    echo_info "Installing code-review-graph..."
    pip install code-review-graph 2>/dev/null || echo_warn "Failed to install code-review-graph"
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
echo "  To update: cd doit-skill && git pull && ./scripts/setup.sh"
echo "  To check dependencies: ./scripts/doctor.sh"
echo ""
