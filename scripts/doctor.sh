#!/bin/bash
# doit doctor - Check dependencies and installation status
# Usage: ./scripts/doctor.sh

set -e

SKILL_DIR="$HOME/.claude/skills"
BUNDLED_SKILLS=("grill-me" "tdd" "diagnose" "prototype" "handoff" "improve-codebase-architecture")
BUILTIN_SKILLS=("code-review" "security-review" "verify" "caveman" "find-skills" "write-a-skill")
EXTERNAL_TOOLS=("context-mode" "rtk" "uv" "codegraph" "code-review-graph" "tavily")

echo "=========================================="
echo "  doit-skill Doctor"
echo "=========================================="
echo ""

# Step 1: Check doit skill installation
echo "[1/3] Checking doit skill installation..."
if [ -d "$SKILL_DIR/doit" ]; then
    echo "  ✅ doit skill installed"
    # Check for core files
    core_files=("SKILL.md" "classifier.md" "spec.md" "plan.md" "execute.md" "e2e.md" "review.md" "review-simplify.md" "commit.md" "errors.md" "setup.md")
    missing_core=""
    for file in "${core_files[@]}"; do
        if [ ! -f "$SKILL_DIR/doit/$file" ]; then
            missing_core="$missing_core $file"
        fi
    done
    if [ -z "$missing_core" ]; then
        echo "  ✅ Core files present"
    else
        echo "  ❌ Missing core files:$missing_core"
    fi
else
    echo "  ❌ doit skill not installed"
    echo "  💡 Run: cd doit-skill && ./scripts/install.sh"
fi
echo ""

# Step 2: Check bundled skills
echo "[2/3] Checking bundled skills..."
for skill in "${BUNDLED_SKILLS[@]}"; do
    if [ -d "$SKILL_DIR/$skill" ]; then
        echo "  ✅ $skill installed"
    else
        echo "  ❌ $skill not installed"
        echo "  💡 Re-run: cd doit-skill && ./scripts/install.sh"
    fi
done
echo ""

# Step 3: Check built-in Claude Code skills
echo "[3/4] Checking built-in Claude Code skills..."
for skill in "${BUILTIN_SKILLS[@]}"; do
    if [ -d "$SKILL_DIR/$skill" ]; then
        echo "  ✅ $skill custom override installed"
    else
        echo "  ℹ️  $skill built-in (no install needed)"
    fi
done
echo ""

# Step 4: Check external tools
echo "[4/4] Checking external tools..."
for tool in "${EXTERNAL_TOOLS[@]}"; do
    case $tool in
        "context-mode")
            if command -v ctx >/dev/null 2>&1; then
                echo "  ✅ context-mode installed"
            else
                echo "  ℹ️  context-mode not installed (recommended)"
                echo "  💡 Install: npx @anthropic/context-mode"
            fi
            ;;
        "rtk")
            if command -v rtk >/dev/null 2>&1; then
                echo "  ✅ rtk installed"
            else
                echo "  ℹ️  rtk not installed (recommended)"
                echo "  💡 Install: cargo install rtk"
            fi
            ;;
        "uv")
            if command -v uv >/dev/null 2>&1; then
                echo "  ✅ uv installed"
            else
                echo "  ℹ️  uv not installed (recommended)"
                echo "  💡 Install: pip install uv"
            fi
            ;;
        "codegraph")
            if command -v codegraph >/dev/null 2>&1; then
                echo "  ✅ codegraph installed"
            else
                echo "  ℹ️  codegraph not installed (recommended)"
                echo "  💡 Install: npx @anthropic/codegraph init"
            fi
            ;;
        "code-review-graph")
            if command -v code-review-graph >/dev/null 2>&1; then
                echo "  ✅ code-review-graph installed"
            else
                echo "  ℹ️  code-review-graph not installed (optional)"
                echo "  💡 Install: pip install code-review-graph"
            fi
            ;;
        "tavily")
            if grep -q "tavily" ~/.claude/settings.json 2>/dev/null || grep -q "tavily" ~/.claude/plugins/*.json 2>/dev/null; then
                echo "  ✅ tavily configured"
            else
                echo "  ℹ️  tavily not configured (optional)"
                echo "  💡 Configure: Add Tavily MCP to ~/.claude/settings.json"
            fi
            ;;
    esac
done
echo ""
echo "=========================================="
echo "  ✅ doit-skill Doctor complete!"
echo "=========================================="
