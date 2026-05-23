#!/bin/bash
# Install doit-skill and its dependencies
# Usage: ./scripts/install.sh [--dry-run]

set -e

SKILL_DIR="$HOME/.claude/skills"
DRY_RUN=false
for arg in "$@"; do
  if [ "$arg" = "--dry-run" ]; then
    DRY_RUN=true
  fi
done

if [ "$DRY_RUN" = true ]; then
  echo "🔍 Dry run — nothing will be installed"
fi

echo "=========================================="
echo "  doit-skill Installer"
echo "=========================================="
echo ""

# Step 1: Copy doit skill (exclude .git, .code-review-graph, .claude/skills)
echo "[1/3] Installing doit skill..."
if [ "$DRY_RUN" = false ]; then
  SKILL_SRC="$(cd "$(dirname "$0")/.." && pwd)"
  SKILL_DST="$SKILL_DIR/doit"

  # Remove existing installation
  rm -rf "$SKILL_DST"

  # Copy with exclusions
  cp -rL "$SKILL_SRC" "$SKILL_DST"

  # Remove excluded directories
  rm -rf "$SKILL_DST/.git"
  rm -rf "$SKILL_DST/.code-review-graph"
  rm -rf "$SKILL_DST/.claude/skills"

  echo "  ✅ doit installed to $SKILL_DST"
fi

# Step 2: Install bundled skills
echo "[2/3] Installing bundled skills..."
for skill in $(ls "$(dirname "$0")/../skills/" 2>/dev/null); do
  if [ "$DRY_RUN" = false ]; then
    cp -r "$(dirname "$0")/../skills/$skill" "$SKILL_DIR/$skill"
    echo "  ✅ $skill installed"
  else
    echo "  📦 would install $skill"
  fi
done

# Step 3: Check external tools
echo "[3/3] Checking external tools..."
echo ""
echo "  Optional tools (install as needed):"
echo "    context-mode     npx @anthropic/context-mode"
echo "    rtk              cargo install rtk"
echo "    uv               pip install uv"
echo "    codegraph        npx @anthropic/codegraph init"
echo "    code-review-graph pip install code-review-graph"
echo ""
echo "=========================================="
echo "  ✅ Installation complete!"
echo "  Run 'claude --help' to verify skills"
echo "=========================================="
