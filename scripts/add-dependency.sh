#!/bin/bash
# Add a new skill dependency to doit-pack
# Usage: ./scripts/add-dependency.sh <skill-name> [bundled|optional|recommended]

set -e

SKILL_NAME="$1"
LEVEL="${2:-bundled}"
PROJECT_ROOT="$(dirname "$0")/.."
SKILL_SOURCE="$HOME/.claude/skills/$SKILL_NAME"

if [ -z "$SKILL_NAME" ]; then
  echo "Usage: $0 <skill-name> [bundled|optional|recommended]"
  echo "Example: $0 code-review recommended"
  exit 1
fi

if [ ! -d "$SKILL_SOURCE" ]; then
  echo "❌ Skill '$SKILL_NAME' not found in $SKILL_SOURCE"
  echo "   Install it first, or manually place it in doit-pack/skills/"
  exit 1
fi

# Copy skill to doit-pack/skills/
cp -r "$SKILL_SOURCE" "$PROJECT_ROOT/skills/$SKILL_NAME"
echo "✅ Copied $SKILL_NAME to doit-pack/skills/"

# Update package.json (simple append — use jq for production)
echo "ℹ️  Update package.json manually:"
echo "    \"dependencies.skills.$SKILL_NAME\": \"$LEVEL\""
echo ""
echo "Or run: node -e \"const p=JSON.parse(require('fs').readFileSync('$PROJECT_ROOT/package.json','utf8')); p.dependencies.skills['$SKILL_NAME']='$LEVEL'; require('fs').writeFileSync('$PROJECT_ROOT/package.json', JSON.stringify(p,null,2))\""
echo ""
echo "✅ Dependency $SKILL_NAME added (level: $LEVEL)"
