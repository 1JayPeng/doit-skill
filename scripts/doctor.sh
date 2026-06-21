#!/bin/bash
# doit doctor - Check dependencies and installation status
# Usage: ./scripts/doctor.sh

set -e

# Detect skill directory: multi-CLI support
# SKILL_DIR env var can override (used by setup.sh when running from temp clone)
# Detect order: project-local takes precedence, then global
if [ -z "$SKILL_DIR" ]; then
  for _dir in ".claude/skills" ".opencode/skills" ".omp/skills" ".mimo/skills" \
              "$HOME/.claude/skills" "$HOME/.opencode/skills" "$HOME/.config/omp/skills" "$HOME/.config/mimo/skills"; do
    if [ -d "$_dir" ]; then
      SKILL_DIR="$_dir"
      break
    fi
  done
  # Fallback
  if [ -z "$SKILL_DIR" ]; then
    SKILL_DIR=".claude/skills"
  fi
fi
GH_PROXY="https://v6.gh-proxy.org"
BUNDLED_SKILLS=("grill-me" "tdd" "diagnose" "prototype" "handoff" "improve-codebase-architecture")
BUILTIN_SKILLS=()
EXTERNAL_TOOLS=("context-mode" "rtk" "uv" "tavily" "caveman" "code-review" "mempalace" "headroom" "lean-ctx")
SHARED_FILES=("core/shared/review-simplify.md" "core/shared/e2e-verify.md" "core/shared/commit.md")
SYMLINK_TARGETS=("review-simplify.md:core/shared/review-simplify.md" "commit.md:core/shared/commit.md")

echo "=========================================="
echo "  doit-skill Doctor"
echo "  Skills dir: $SKILL_DIR"
echo "=========================================="
echo ""

# Step 1: Check doit skill installation
echo "[1/3] Checking doit skill installation..."
if [ -d "$SKILL_DIR/doit" ]; then
    echo "  ✅ doit skill installed"
    # Check for core files
    core_files=("SKILL.md" "core/iron-rules.md" "core/workflow.md" "classifier.md" "spec.md" "plan.md" "core/execute.md" "e2e.md" "review.md" "core/shared/review-simplify.md" "core/shared/commit.md" "errors.md" "setup.md")
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
fi
echo ""

# Step 2: Check bundled skills
echo "[2/3] Checking bundled skills..."
for skill in "${BUNDLED_SKILLS[@]}"; do
    if [ -d "$SKILL_DIR/$skill" ]; then
        echo "  ✅ $skill installed"
    else
        echo "  ❌ $skill not installed"
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
            elif grep -rl "context-mode" "$HOME/.claude/plugins/" > /dev/null 2>&1; then
                echo "  ✅ context-mode installed (plugin)"
            else
                echo "  ℹ️ context-mode not installed (recommended)"
            fi
            ;;
        "rtk")
            if command -v rtk >/dev/null 2>&1; then
                echo "  ✅ rtk installed"
            else
                echo "  ℹ️  rtk not installed (recommended)"
            fi
            ;;
        "uv")
            if command -v uv >/dev/null 2>&1; then
                echo "  ✅ uv installed"
            else
                echo "  ℹ️  uv not installed (recommended)"
            fi
            ;;
        "rust")
            if command -v cargo >/dev/null 2>&1; then
                echo "  ✅ rust/cargo installed"
            else
                echo "  ℹ️  rust not installed (required for rtk)"
            fi
            ;;
        "tavily")
            if claude mcp list 2>/dev/null | grep -q tavily; then
                echo "  ✅ tavily configured (MCP)"
            elif grep -q "tavily" ~/.claude/settings.json 2>/dev/null; then
                echo "  ✅ tavily configured (settings.json)"
            else
                echo "  ℹ️  tavily not configured (optional)"
            fi
            ;;
        "caveman")
            if [ -d "$SKILL_DIR/caveman" ]; then
                echo "  ✅ caveman installed (skill)"
            elif grep -rl "caveman" "$HOME/.claude/plugins/" > /dev/null 2>&1; then
                echo "  ✅ caveman installed (plugin)"
            elif [ -f "$HOME/.claude/hooks/caveman.sh" ] || [ -f "$HOME/.claude/hooks/caveman-hook.sh" ]; then
                echo "  ✅ caveman installed (hooks)"
            else
                echo "  ℹ️  caveman not installed (recommended)"
            fi
            ;;
        "code-review")
            if [ -d "$SKILL_DIR/code-review" ]; then
                echo "  ✅ code-review installed (skill)"
            elif grep -rl "code-review" "$HOME/.claude/plugins/" > /dev/null 2>&1; then
                echo "  ✅ code-review installed (plugin)"
            else
                echo "  ℹ️  code-review not installed (recommended)"
            fi
            ;;
        "mempalace")
            if grep -rl "mempalace" "$HOME/.claude/plugins/" > /dev/null 2>&1; then
                echo "  ✅ mempalace installed (plugin)"
            else
                echo "  ℹ️  mempalace plugin not installed (recommended)"
            fi
            if command -v mempalace >/dev/null 2>&1; then
                echo "  ✅ mempalace CLI installed"
            else
                echo "  ℹ️  mempalace CLI not installed"
            fi
            if [ -d ".mempalace" ]; then
                echo "  ✅ mempalace initialized"
            else
                echo "  ℹ️  mempalace not initialized"
            fi
            ;;
        "headroom")
            if command -v headroom >/dev/null 2>&1; then
                echo "  ✅ headroom installed"
            else
                echo "  ℹ️  headroom not installed (recommended)"
            fi
            if claude mcp list 2>/dev/null | grep -q headroom; then
                echo "  ✅ headroom MCP configured"
            else
                echo "  ℹ️  headroom MCP not configured"
            fi
            ;;
        "lean-ctx")
            if command -v lean-ctx >/dev/null 2>&1; then
                echo "  ✅ lean-ctx installed"
            else
                echo "  ℹ️  lean-ctx not installed (recommended)"
            fi
            if [ -f ".claude/rules/lean-ctx.md" ]; then
                echo "  ✅ lean-ctx rules configured (project-local)"
            elif [ -f "$HOME/.claude/rules/lean-ctx.md" ]; then
                echo "  ✅ lean-ctx rules configured (global)"
            else
                echo "  ℹ️  lean-ctx rules not configured"
            fi
            ;;
    esac
done
echo ""
echo "=========================================="
echo "  ✅ doit-skill Doctor complete!"
echo "=========================================="
