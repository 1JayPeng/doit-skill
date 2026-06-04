#!/bin/bash
# Add a new skill dependency to doit-skill
# Usage: ./scripts/add-dependency.sh <skill-name> [bundled|optional|recommended]

set -e

SKILL_NAME="$1"
LEVEL="${2:-bundled}"
PROJECT_ROOT="$(dirname "$0")/.."

# Validate skill name: only allow safe characters
if [[ ! "$SKILL_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "❌ Invalid skill name: '$SKILL_NAME'"
  echo "   Only letters, numbers, hyphens, and underscores allowed."
  exit 1
fi

# Validate level
case "$LEVEL" in
  bundled|optional|recommended) ;;
  *) echo "❌ Invalid level: '$LEVEL'. Use: bundled, optional, recommended"; exit 1 ;;
esac

# Check skill source (project-local first, then global)
if [ -d ".claude/skills/$SKILL_NAME" ]; then
  SKILL_SOURCE=".claude/skills/$SKILL_NAME"
elif [ -d "$HOME/.claude/skills/$SKILL_NAME" ]; then
  SKILL_SOURCE="$HOME/.claude/skills/$SKILL_NAME"
else
  echo "❌ Skill '$SKILL_NAME' not found"
  echo "   Install it first, or manually place it in skills/$SKILL_NAME/"
  exit 1
fi

# Copy skill to skills/ directory, excluding hidden files
rsync -a --exclude='.git' --exclude='.*' "$SKILL_SOURCE/" "$PROJECT_ROOT/skills/$SKILL_NAME/" 2>/dev/null \
  || cp -r "$SKILL_SOURCE" "$PROJECT_ROOT/skills/$SKILL_NAME"
echo "✅ Copied $SKILL_NAME to skills/"

# Update package.json safely using node with escaped arguments
if [ -f "$PROJECT_ROOT/package.json" ]; then
  node -e "
    const fs = require('fs');
    const skillName = process.argv[1];
    const level = process.argv[2];
    const path = process.argv[3];
    const p = JSON.parse(fs.readFileSync(path, 'utf8'));
    if (!p.dependencies) p.dependencies = {};
    if (!p.dependencies.skills) p.dependencies.skills = {};
    p.dependencies.skills[skillName] = level;
    fs.writeFileSync(path, JSON.stringify(p, null, 2));
  " "$SKILL_NAME" "$LEVEL" "$PROJECT_ROOT/package.json"
  echo "✅ Updated package.json"
fi

echo "✅ Dependency $SKILL_NAME added (level: $LEVEL)"
