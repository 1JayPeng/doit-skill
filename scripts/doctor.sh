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
EXTERNAL_TOOLS=("context-mode" "rtk" "uv" "tavily" "caveman" "mempalace" "headroom" "lean-ctx")
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
                echo "     Install: claude plugin install context-mode@claude-context-mode/plugin"
            fi
            ;;
        "rtk")
            if command -v rtk >/dev/null 2>&1; then
                echo "  ✅ rtk installed"
            else
                echo "  ℹ️  rtk not installed (recommended)"
                echo "     Install: cargo install rtk"
            fi
            ;;
        "uv")
            if command -v uv >/dev/null 2>&1; then
                echo "  ✅ uv installed"
            else
                echo "  ℹ️  uv not installed (recommended)"
                echo "     Install: curl -LsSf https://astral.sh/uv/install.sh | sh"
            fi
            ;;
        "rust")
            if command -v cargo >/dev/null 2>&1; then
                echo "  ✅ rust/cargo installed"
            else
                echo "  ℹ️  rust not installed (required for rtk)"
                echo "     Install: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
            fi
            ;;
        "tavily")
            if claude mcp list 2>/dev/null | grep -q tavily; then
                echo "  ✅ tavily configured (MCP)"
            elif grep -q "tavily" ~/.claude/settings.json 2>/dev/null; then
                echo "  ✅ tavily configured (settings.json)"
            else
                echo "  ℹ️  tavily not configured (optional)"
                echo "     Configure: claude mcp add tavily --transport http --env TAVILY_API_KEY=\$TAVILY_API_KEY 'https://api.tavily.com/v1/mcp'"
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
                echo "     Install: claude plugin install caveman@caveman"
            fi
            ;;
        "mempalace")
            if grep -rl "mempalace" "$HOME/.claude/plugins/" > /dev/null 2>&1; then
                echo "  ✅ mempalace installed (plugin)"
            else
                echo "  ℹ️  mempalace plugin not installed (recommended)"
                echo "     Install: claude plugin add mempalace@mempalace --marketplace github:milla-jovovich/mempalace"
            fi
            if command -v mempalace >/dev/null 2>&1; then
                echo "  ✅ mempalace CLI installed"
            else
                echo "  ℹ️  mempalace CLI not installed"
                echo "     Install: uv tool install mempalace"
            fi
            if [ -d ".mempalace" ]; then
                echo "  ✅ mempalace initialized"
            else
                echo "  ℹ️  mempalace not initialized"
                echo "     Initialize: mempalace init . --yes"
            fi
            ;;
        "headroom")
            if command -v headroom >/dev/null 2>&1; then
                echo "  ✅ headroom installed"
            else
                echo "  ℹ️  headroom not installed (recommended)"
                echo "     Install: uv tool install 'headroom-ai[mcp,proxy]'"
            fi
            if claude mcp list 2>/dev/null | grep -q headroom; then
                echo "  ✅ headroom MCP configured"
            else
                echo "  ℹ️  headroom MCP not configured"
                echo "     Configure: headroom mcp install"
            fi
            ;;
        "lean-ctx")
            if command -v lean-ctx >/dev/null 2>&1; then
                echo "  ✅ lean-ctx installed"
            else
                echo "  ℹ️  lean-ctx not installed (recommended)"
                echo "     Install: curl -fsSL https://leanctx.com/install.sh | sh"
            fi
            if [ -f ".claude/rules/lean-ctx.md" ]; then
                echo "  ✅ lean-ctx rules configured (project-local)"
            elif [ -f "$HOME/.claude/rules/lean-ctx.md" ]; then
                echo "  ✅ lean-ctx rules configured (global)"
            else
                echo "  ℹ️  lean-ctx rules not configured"
                echo "     Configure: lean-ctx onboard (auto-detects CLI)"
            fi
            ;;
    esac
done

# codegraph (separate check - not in case block)
echo "  Checking codegraph..."
if command -v codegraph >/dev/null 2>&1; then
    echo "  ✅ codegraph installed"
else
    echo "  ℹ️  codegraph not installed (recommended)"
    echo "     Install: npm i -g @colbymchenry/codegraph"
fi
if [ -d ".codegraph" ]; then
    echo "  ✅ codegraph index initialized"
else
    echo "  ℹ️  codegraph index not initialized"
    echo "     Initialize: codegraph init -i"
fi
echo ""
echo "=========================================="
echo "  ✅ doit-skill Doctor complete!"
echo "=========================================="
