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

# Ask about doc-capture (interactive, skip if piped/non-tty)
DOC_CAPTURE="true"
if [ -t 0 ] && [ -t 1 ]; then
  read -r -p "Enable doc-capture (persist reference docs in .doit/docs/)? [Y/n] " answer
  case "${answer:-Y}" in
    [yY][eE][sS]|[yY]) DOC_CAPTURE="true" ;;
    *) DOC_CAPTURE="false" ;;
  esac
fi

# Write user config
SKILL_CONFIG="$SKILL_DIR/doit-config.yaml"
cat > "$SKILL_CONFIG" <<EOF
doc-capture:
  enabled: $DOC_CAPTURE
  mode: auto
  path: .doit/docs

commit:
  branch: branch
  feat_prefix: feat
  fix_prefix: fix
  refactor_prefix: refactor
EOF

# Step 1: Copy doit skill (exclude .git, .tokensave, .claude/skills)
echo "[1/3] Installing doit skill..."
if [ "$DRY_RUN" = false ]; then
  SKILL_SRC="$(cd "$(dirname "$0")/.." && pwd)"
  SKILL_DST="$SKILL_DIR/doit"

  # Remove existing installation
  rm -rf "$SKILL_DST"

  # Copy — preserve symlinks (shared phases)
  cp -a "$SKILL_SRC" "$SKILL_DST"

  # Remove excluded directories
  rm -rf "$SKILL_DST/.git"
  rm -rf "$SKILL_DST/.tokensave"
  rm -rf "$SKILL_DST/.claude/skills"

  echo "  ✅ doit installed to $SKILL_DST"
  for lnk in review-simplify.md commit.md; do
    if [ -L "$SKILL_DST/$lnk" ]; then
      echo "  ✅ $lnk -> $(readlink "$SKILL_DST/$lnk") (symlink OK)"
    else
      echo "  ⚠️  $lnk is not a symlink"
    fi
  done
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
echo "    tokensave        cargo install tokensave"
echo ""
echo "=========================================="
echo "  ✅ Installation complete!"
echo "  Run 'claude --help' to verify skills"
echo "=========================================="
