#!/bin/bash
# doit doctor - Check dependencies and installation status
# Usage: ./scripts/doctor.sh

set -e

SKILL_DIR="$HOME/.claude/skills"
BUNDLED_SKILLS=("grill-me" "tdd" "diagnose" "prototype" "handoff" "improve-codebase-architecture")
BUILTIN_SKILLS=()
EXTERNAL_TOOLS=("context-mode" "rtk" "uv" "tokensave" "tavily" "caveman" "code-review" "mempalace")
SHARED_FILES=("shared/review-simplify.md" "shared/e2e-verify.md" "shared/commit.md")
SYMLINK_TARGETS=("review-simplify.md:shared/review-simplify.md" "commit.md:shared/commit.md")

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

    # Check shared phases
    echo "  Checking shared phases..."
    for sf in "${SHARED_FILES[@]}"; do
        if [ -f "$SKILL_DIR/doit/$sf" ]; then
            echo "  ✅ $sf present"
        else
            echo "  ❌ $sf missing — re-run install"
        fi
    done

    # Check symlinks are correct
    for lnk in "${SYMLINK_TARGETS[@]}"; do
        file="${lnk%%:*}"
        target="${lnk##*:}"
        if [ -L "$SKILL_DIR/doit/$file" ]; then
            actual=$(readlink "$SKILL_DIR/doit/$file")
            if [ "$actual" = "$target" ]; then
                echo "  ✅ $file -> $target (symlink OK)"
            else
                echo "  ⚠️  $file -> $actual (expected $target)"
            fi
        else
            echo "  ⚠️  $file is not a symlink — running without shared phases"
        fi
    done
else
    echo "  ❌ doit skill not installed"
    echo "  💡 Run: cd doit-skill && ./scripts/setup.sh"
fi
echo ""

# Step 2: Check bundled skills
echo "[2/3] Checking bundled skills..."
for skill in "${BUNDLED_SKILLS[@]}"; do
    if [ -d "$SKILL_DIR/$skill" ]; then
        echo "  ✅ $skill installed"
    else
        echo "  ❌ $skill not installed"
        echo "  💡 Re-run: cd doit-skill && ./scripts/setup.sh"
    fi
done
echo ""

# Step 3: Check external tools
echo "[3/3] Checking external tools..."
for tool in "${EXTERNAL_TOOLS[@]}"; do
    case $tool in
"context-mode")
            if command -v ctx >/dev/null 2>&1; then
                echo "  ✅ context-mode installed (CLI)"
            elif grep -rl "context-mode" "$HOME/.claude/plugins/" 2>/dev/null; then
                echo "  ✅ context-mode installed (plugin)"
            else
                echo "  ℹ️ context-mode not installed (recommended)"
                echo "  💡 Install: claude plugin marketplace add mksglu/context-mode"
                echo "     claude plugin install context-mode@context-mode"
            fi
            ;;
        "rtk")
            if command -v rtk >/dev/null 2>&1; then
                echo "  ✅ rtk installed"
            else
                echo "  ℹ️  rtk not installed (recommended)"
                echo "  💡 Install: curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh"
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
        "tokensave")
            if command -v tokensave >/dev/null 2>&1; then
                echo "  ✅ tokensave installed"
            else
                echo "  ℹ️  tokensave not installed (recommended)"
                echo "  💡 Install: cargo install tokensave && tokensave install --agent claude"
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
        "caveman")
            if [ -d "$SKILL_DIR/caveman" ]; then
                echo "  ✅ caveman installed (skill)"
            elif grep -rl "caveman" "$HOME/.claude/plugins/" 2>/dev/null; then
                echo "  ✅ caveman installed (plugin)"
            elif grep -rl "caveman" "$HOME/.claude/hooks/" 2>/dev/null; then
                echo "  ✅ caveman installed (hooks)"
            else
                echo "  ℹ️  caveman not installed (recommended)"
                echo "  💡 Install: curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash"
            fi
            ;;
        "code-review")
            if [ -d "$SKILL_DIR/code-review" ]; then
                echo "  ✅ code-review installed (skill)"
            elif grep -rl "code-review" "$HOME/.claude/plugins/" 2>/dev/null; then
                echo "  ✅ code-review installed (plugin)"
            else
                echo "  ℹ️  code-review not installed (recommended)"
                echo "  💡 Install: claude plugin install code-review"
            fi
            ;;
        "mempalace")
            if grep -rl "mempalace" "$HOME/.claude/plugins/" 2>/dev/null; then
                echo "  ✅ mempalace installed (plugin)"
            else
                echo "  ℹ️  mempalace not installed (recommended)"
                echo "  💡 Install: claude plugin marketplace add MemPalace/mempalace"
                echo "     claude plugin install --scope user mempalace"
            fi
            ;;
    esac
done
echo ""
echo "=========================================="
echo "  ✅ doit-skill Doctor complete!"
echo "=========================================="
