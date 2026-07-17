#!/bin/bash
# doit doctor - Check dependencies and installation status
# Usage: ./scripts/doctor.sh

set -e

# Detect skill directory: project-local .claude/skills/ takes precedence over global ~/.claude/skills/
# SKILL_DIR env var can override (used by setup.sh when running from temp clone)
if [ -z "$SKILL_DIR" ]; then
  if [ -d ".claude/skills" ]; then
    SKILL_DIR=".claude/skills"
  else
    SKILL_DIR="$HOME/.claude/skills"
  fi
fi
GH_PROXY="https://v6.gh-proxy.org"
BUNDLED_SKILLS=("grill-me" "tdd" "diagnose" "prototype" "handoff" "improve-codebase-architecture")
BUILTIN_SKILLS=()
EXTERNAL_TOOLS=("context-mode" "rtk" "uv" "rust" "tavily" "caveman" "code-review" "mempalace" "headroom" "lean-ctx" "codegraph" "ponytail")
SHARED_FILES=("core/shared/review-simplify.md" "core/shared/e2e-verify.md" "core/shared/commit.md")
SYMLINK_TARGETS=("review-simplify.md:core/shared/review-simplify.md" "commit.md:core/shared/commit.md")

# Detect which CLI agent is in use (mirrors setup.sh detect_agent with auto resolution)
_detect_agent() {
  local agent="${1:-auto}"
  if [ "$agent" = "auto" ]; then
    # OMP takes priority when installed alongside Claude
    command -v omp >/dev/null 2>&1 && echo "oh-my-pi" && return
    if [ -d ".claude/skills" ] || [ -d "$HOME/.claude/skills" ] || command -v claude >/dev/null 2>&1; then
      echo "claude" && return
    fi
    command -v opencode >/dev/null 2>&1 && echo "opencode" && return
    command -v codex >/dev/null 2>&1 && echo "codex" && return
    command -v omp >/dev/null 2>&1 && echo "oh-my-pi" && return
    command -v mimo >/dev/null 2>&1 && echo "mimo" && return
    command -v jcode >/dev/null 2>&1 && echo "jcode" && return
    echo "claude" && return  # fallback
  fi
  echo "$agent"
}

# Resolved agent type for tool checks
_agent_type=$(_detect_agent "auto")

# Helper: check plugin installed (supports both Claude and OMP)
_check_plugin() {
    local plugin_name="$1"
    if [ "$_agent_type" = "oh-my-pi" ]; then
        omp plugin list 2>/dev/null | grep -q "$plugin_name" && return 0
        grep -rl --include="*.json" --include="*.md" --max-count=1 "$plugin_name" "$HOME/.omp/plugins/" > /dev/null 2>&1 && return 0
        return 1
    else
        claude plugin list 2>/dev/null | grep -q "$plugin_name" && return 0
        grep -rl --include="*.json" --include="*.md" --max-count=1 "$plugin_name" "$HOME/.claude/plugins/" > /dev/null 2>&1 && return 0
        return 1
    fi
}

# Helper: check MCP configured (supports both Claude and OMP)
_check_mcp() {
    local mcp_name="$1"
    if [ "$_agent_type" = "oh-my-pi" ]; then
        timeout 3 omp mcp list 2>/dev/null | grep -qi "$mcp_name" && return 0
        grep -qi "$mcp_name" "$HOME/.config/omp/mcp.json" 2>/dev/null && return 0
        return 1
    else
        claude mcp list 2>/dev/null | grep -qi "$mcp_name" && return 0
        grep -qi "$mcp_name" "$HOME/.claude.json" 2>/dev/null && return 0
        return 1
    fi
}

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
    core_files=("SKILL.md" "core/iron-rules.md" "core/workflow.md" "core/phase-0.md" "core/phase-1.md" "core/execute.md" "core/env-check.md" "classifier.md" "spec.md" "plan.md" "e2e.md" "review.md" "errors.md" "setup.md")
    root_symlinks=("review-simplify.md" "commit.md")
    missing_core=""
    for file in "${core_files[@]}"; do
        if [ ! -f "$SKILL_DIR/doit/$file" ]; then
            missing_core="$missing_core $file"
        fi
    done
    for lnk in "${root_symlinks[@]}"; do
        if [ ! -e "$SKILL_DIR/doit/$lnk" ]; then
            missing_core="$missing_core $lnk"
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
    case "$tool" in
        "context-mode")
                if command -v ctx >/dev/null 2>&1; then
                    echo "  ✅ context-mode installed (CLI)"
                elif _check_plugin "context-mode"; then
                    echo "  ✅ context-mode installed (plugin)"
                else
                    echo "  ℹ️ context-mode not installed (recommended)"
                    if [ "$_agent_type" = "oh-my-pi" ]; then
                        echo "  💡 Install: omp plugin install context-mode"
                    else
                        echo "  💡 Install: claude plugin marketplace add mksglu/claude-context-mode/plugin"
                        echo "     claude plugin install context-mode@claude-context-mode/plugin"
                    fi
                fi
                ;;
            "rtk")
                if command -v rtk >/dev/null 2>&1; then
                    echo "  ✅ rtk installed"
                else
                    echo "  ℹ️  rtk not installed (recommended)"
                    echo "  💡 Install: curl -fsSL ${GH_PROXY}/https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh"
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
        "rust")
            if command -v cargo >/dev/null 2>&1; then
                echo "  ✅ rust/cargo installed"
            else
                echo "  ℹ️  rust not installed (required for rtk)"
                echo "  💡 Install: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
            fi
            ;;
        "tavily")
            if _check_mcp "tavily"; then
                echo "  ✅ tavily configured (MCP)"
            elif grep -q "tavily" ~/.claude/settings.json 2>/dev/null; then
                echo "  ✅ tavily configured (settings.json)"
            else
                echo "  ℹ️  tavily not configured (optional)"
                if [ "$_agent_type" = "oh-my-pi" ]; then
                    echo "  💡 Configure: add to $HOME/.config/omp/mcp.json"
                else
                    echo "  💡 Configure: claude mcp add --transport http tavily https://mcp.tavily.com/mcp/?tavilyApiKey=<your-key>"
                fi
            fi
            ;;
        "caveman")
            if [ -d "$SKILL_DIR/caveman" ]; then
                echo "  ✅ caveman installed (skill)"
            elif [ "$_agent_type" = "oh-my-pi" ]; then
                echo "  ❌ caveman is Claude-only, not available for OMP"
            elif _check_plugin "caveman"; then
                echo "  ✅ caveman installed (plugin)"
            elif [ -f "$HOME/.claude/hooks/caveman.sh" ] || [ -f "$HOME/.claude/hooks/caveman-hook.sh" ]; then
                echo "  ✅ caveman installed (hooks)"
            else
                echo "  ℹ️  caveman not installed (recommended)"
                echo "  💡 Install: curl -fsSL ${GH_PROXY}/https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash"
            fi
            ;;
        "code-review")
            if [ -d "$SKILL_DIR/code-review" ]; then
                echo "  ✅ code-review installed (skill)"
            elif [ "$_agent_type" = "oh-my-pi" ]; then
                echo "  ❌ code-review is Claude-only, not available for OMP"
            elif _check_plugin "code-review"; then
                echo "  ✅ code-review installed (plugin)"
            else
                echo "  ℹ️  code-review not installed (recommended)"
                echo "  💡 Install: claude plugin install code-review"
            fi
            ;;
        "mempalace")
            if _check_plugin "mempalace"; then
                echo "  ✅ mempalace installed (plugin)"
            else
                echo "  ℹ️  mempalace plugin not installed (recommended)"
                if [ "$_agent_type" = "oh-my-pi" ]; then
                    echo "  💡 Install: omp plugin install mempalace"
                else
                    echo "  💡 Install: claude plugin add mempalace@mempalace --marketplace github:milla-jovovich/mempalace"
                fi
            fi
            if command -v mempalace >/dev/null 2>&1; then
                echo "  ✅ mempalace CLI installed"
            else
                echo "  ℹ️  mempalace CLI not installed"
                echo "  💡 Install: uv tool install mempalace"
            fi
            # Check initialized in CWD or walking up to 3 parent dirs
            _mp_found=""
            _mp_check_dir="$PWD"
            for _i in 1 2 3 4; do
                if [ -d "$_mp_check_dir/.mempalace" ] || [ -f "$_mp_check_dir/mempalace.yaml" ]; then
                    _mp_found="$_mp_check_dir"
                    break
                fi
                _mp_check_dir="$(dirname "$_mp_check_dir")"
                [ "$_mp_check_dir" = "/" ] && break
            done
            if [ -n "$_mp_found" ]; then
                echo "  ✅ mempalace initialized ($_mp_found)"
            else
                echo "  ℹ️  mempalace not initialized"
                echo "  💡 Run: mempalace init ."
            fi
            ;;
        "headroom")
            if command -v headroom >/dev/null 2>&1; then
                echo "  ✅ headroom installed"
            else
                echo "  ℹ️  headroom not installed (recommended — MCP only is OK)"
                echo "  💡 Install: uv tool install 'headroom-ai[mcp,proxy]'"
            fi
            # MCP check independent of CLI presence
            if _check_mcp "headroom"; then
                echo "  ✅ headroom MCP configured (fallback tools)"
            else
                echo "  ℹ️  headroom MCP not configured"
                echo "  💡 Configure: headroom mcp install"
            fi
            # Check persistent proxy deployment
            if timeout 3 curl -sf http://127.0.0.1:8787/health >/dev/null 2>&1; then
                echo "  ✅ headroom proxy running (health OK)"
            else
                echo "  ℹ️  headroom proxy not running"
                echo "  💡 Deploy: headroom install apply --preset persistent-service"
            fi
            ;;
        "lean-ctx")
            if command -v lean-ctx >/dev/null 2>&1; then
                echo "  ✅ lean-ctx installed"
            else
                echo "  ℹ️  lean-ctx not installed (recommended)"
                echo "  💡 Install: curl -fsSL https://leanctx.com/install.sh | sh && lean-ctx onboard"
            fi
            if [ "$_agent_type" = "oh-my-pi" ]; then
                if [ -f "$HOME/.config/omp/rules/lean-ctx.md" ]; then
                    echo "  ✅ lean-ctx rules configured (project-local)"
                elif [ -f "$HOME/.config/omp/rules/lean-ctx.md" ]; then
                    echo "  ✅ lean-ctx rules configured (global)"
                else
                    echo "  ℹ️  lean-ctx rules not configured"
                    echo "  💡 Run: lean-ctx init --agent oh-my-pi"
                fi
            else
                if [ -f ".claude/rules/lean-ctx.md" ]; then
                    echo "  ✅ lean-ctx rules configured (project-local)"
                elif [ -f "$HOME/.claude/rules/lean-ctx.md" ]; then
                    echo "  ✅ lean-ctx rules configured (global)"
                elif [ -f "../.claude/rules/lean-ctx.md" ]; then
                    echo "  ✅ lean-ctx rules configured (project parent)"
                else
                    echo "  ℹ️  lean-ctx rules not configured"
                    echo "  💡 Run: lean-ctx init --agent $(_detect_agent)"
                fi
            fi
            ;;
        "codegraph")
            if command -v codegraph >/dev/null 2>&1; then
                echo "  ✅ codegraph installed"
            else
                echo "  ℹ️  codegraph not installed (recommended)"
                echo "  💡 Install: npm i -g @colbymchenry/codegraph"
            fi
            if _check_mcp "codegraph"; then
                echo "  ✅ codegraph MCP configured"
            else
                echo "  ℹ️  codegraph MCP not configured"
                echo "  💡 Configure: codegraph install --yes"
            fi
            if [ -d ".codegraph" ]; then
                echo "  ✅ codegraph index initialized"
            else
                echo "  ℹ️  codegraph index not initialized"
                echo "  💡 Run: codegraph init -i"
            fi
            ;;
        "ponytail")
            if _check_plugin "ponytail"; then
                echo "  ✅ ponytail installed (plugin)"
            else
                echo "  ℹ️  ponytail not installed (recommended)"
                if [ "$_agent_type" = "oh-my-pi" ]; then
                    echo "  💡 Install: omp plugin install ponytail"
                else
                    echo "  💡 Install: claude plugin marketplace add DietrichGebert/ponytail"
                    echo "     claude plugin install ponytail@ponytail"
                fi
            fi
            ;;
    esac
done
echo ""
echo "=========================================="
echo "  ✅ doit-skill Doctor complete!"
echo "=========================================="
