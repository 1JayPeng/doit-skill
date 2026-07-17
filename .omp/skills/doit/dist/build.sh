#!/bin/bash
# Build distributable package for doit-skill
# Usage: ./dist/build.sh
#
# Creates a tarball of all distributable files, excluding dev-only content.
# The tarball is what gets pushed to GitHub and installed by setup.sh.
#
# Dev-only files excluded:
# - .doit/config.yaml (dev has subagent:true, dist has subagent:false)
# - .git/, .tokensave/, .codegraph/
# - .env, data/, headroom_memory.db
# - Local MemPalace files

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$REPO_ROOT/dist/output"
TAR_NAME="doit-skill-dist.tar.gz"

echo "Building distributable package..."
echo "  Source: $REPO_ROOT"
echo "  Output: $OUTPUT_DIR/$TAR_NAME"

mkdir -p "$OUTPUT_DIR"

# Build tarball excluding dev-only files
tar czf "$OUTPUT_DIR/$TAR_NAME" \
  --exclude='.git' \
  --exclude='.tokensave' \
  --exclude='.codegraph' \
  --exclude='.doit' \
  --exclude='.env' \
  --exclude='data' \
  --exclude='headroom_memory.db' \
  --exclude='entities.json' \
  --exclude='mempalace.yaml' \
  --exclude='dist/output' \
  --exclude='dist/*.tar.gz' \
  --exclude='.claude/skills' \
  --exclude='skills' \
  --exclude='node_modules' \
  --exclude='.venv' \
  --exclude='__pycache__' \
  --exclude='.scratch' \
  --exclude='.spec' \
  -C "$(dirname "$REPO_ROOT")" \
  "$(basename "$REPO_ROOT")"

echo "Built: $OUTPUT_DIR/$TAR_NAME ($(du -sh "$OUTPUT_DIR/$TAR_NAME" | cut -f1))"
echo "Files: $(tar tzf "$OUTPUT_DIR/$TAR_NAME" | wc -l | tr -d ' ')"

# Verify no dev config leaked in
if tar tzf "$OUTPUT_DIR/$TAR_NAME" | grep -q '\.doit/config\.yaml'; then
  echo "ERROR: .doit/config.yaml found in distribution!"
  exit 1
fi

echo "OK: No dev config in distribution"
