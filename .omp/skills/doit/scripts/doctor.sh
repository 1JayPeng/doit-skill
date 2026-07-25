#!/bin/bash
# doit doctor - Check dependencies and installation status
# Usage: ./scripts/doctor.sh
#
# Multi-agent aware: detects ALL installed AI coding CLIs and reports
# tool status for each. CLI-only tools (rtk, uv, headroom, codegraph,
# mempalace CLI) are checked once; plugin/MCP status is


# Detect skill directory: project-local .claude/skills/ takes precedence over global ~/.claude/skills/
# SKILL_DIR env var can override (used by setup.sh when running from temp clone)
if [ -z "$SKILL_DIR" ]; then
  if [ -d ".claude/skills" ]; then
    SKILL_DIR=".claude/skills"
  elif [ -d ".omp/skills" ]; then
    SKILL_DIR=".omp/skills"
  elif [ -d ".opencode/skills" ]; then
    SKILL_DIR=".opencode/skills"
  elif [ -d ".agents/skills" ]; then
    SKILL_DIR=".agents/skills"
  elif [ -d ".mimo/skills" ]; then
    SKILL_DIR=".mimo/skills"
  elif [ -d ".jcode/skills" ]; then
    SKILL_DIR=".jcode/skills"
  else
    SKILL_DIR="$HOME/.claude/skills"
  fi
fi
# Shared tool metadata — single source of truth for setup + doctor
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$DOIT_DIR/scripts/tools.sh"

GH_PROXY="https://v6.gh-proxy.org"
BUNDLED_SKILLS=("grill-me" "tdd" "diagnose" "prototype" "handoff" "improve-codebase-architecture")
BUILTIN_SKILLS=()

CLAUDE_ONLY_TOOLS=("caveman" "code-review")
OMP_CLAUDE_TOOLS=("context-mode" "mempalace" "ponytail")
ALL_AGENT_TOOLS=( $ALL_TOOLS )
SHARED_FILES=("core/shared/review-simplify.md" "core/shared/e2e-verify.md" "core/shared/commit.md")
SYMLINK_TARGETS=("review-simplify.md:core/shared/review-simplify.md" "commit.md:core/shared/review-simplify.md")

# Detect ALL installed AI coding CLIs (space-separated list).
# Mirrors setup.sh detect_all_agents so doctor and installer agree.
_detect_all_agents() {
  local agents=()
  command -v claude   >/dev/null 2>&1 && agents+=(claude)
  command -v opencode >/dev/null 2>&1 && agents+=(opencode)
  command -v codex    >/dev/null 2>&1 && agents+=(codex)
  command -v omp      >/dev/null 2>&1 && agents+=(oh-my-pi)
  command -v mimo     >/dev/null 2>&1 && agents+=(mimo)
  command -v jcode    >/dev/null 2>&1 && agents+=(jcode)
  # Also detect via skills directory presence (CLI may be uninstalled but skills exist)
  [ ${#agents[@]} -eq 0 ] && [ -d ".claude/skills" ] && agents+=(claude)
  [ ${#agents[@]} -eq 0 ] && [ -d ".omp/skills" ] && agents+=(oh-my-pi)
  if [ ${#agents[@]} -eq 0 ]; then
    agents+=(claude)  # fallback
  fi
  echo "${agents[@]}"
}

# Detect primary agent (first detected — used for skill_dir resolution fallback)
_detect_agent() {
  _detect_all_agents | awk '{print $1}'
}

AGENT_LIST=$(_detect_all_agents)
_agent_type=$(echo "$AGENT_LIST" | awk '{print $1}')  # backward compat for helpers

_agent_project_skill_dir() {
    case "$1" in
        claude)   echo ".claude/skills" ;;
        opencode) echo ".opencode/skills" ;;
        codex)    echo ".agents/skills" ;;
        oh-my-pi) echo ".omp/skills" ;;
        mimo)     echo ".mimo/skills" ;;
        jcode)    echo ".jcode/skills" ;;
        *)        echo ".ai/skills" ;;
    esac
}

_agent_global_skill_dir() {
    case "$1" in
        claude)   echo "$HOME/.claude/skills" ;;
        opencode) echo "$HOME/.config/opencode/skills" ;;
        codex)    echo "$HOME/.codex/skills" ;;
        oh-my-pi) echo "$HOME/.config/omp/skills" ;;
        mimo)     echo "$HOME/.config/mimo/skills" ;;
        jcode)    echo "$HOME/.jcode/skills" ;;
        *)        echo "$HOME/.$1/skills" ;;
    esac
}

_agent_skill_dir() {
    local project_dir global_dir
    if [ "$(echo "$AGENT_LIST" | wc -w)" -eq 1 ] && [ -n "${SKILL_DIR:-}" ]; then
        echo "$SKILL_DIR"
        return
    fi
    project_dir=$(_agent_project_skill_dir "$1")
    global_dir=$(_agent_global_skill_dir "$1")
    [ -d "$project_dir" ] && echo "$project_dir" && return
    [ -d "$global_dir" ] && echo "$global_dir" && return
    echo "$project_dir"
}

# Helper: check plugin installed for a SPECIFIC agent
# Usage: _check_plugin_for <agent> <plugin_name>
_check_plugin_for() {
    local agent="$1"
    local plugin_name="$2"
    case "$agent" in
        oh-my-pi)
            omp plugin list 2>/dev/null | grep -q "$plugin_name" && return 0
            grep -rl --include="*.json" --include="*.md" --max-count=1 "$plugin_name" "$HOME/.omp/plugins/" > /dev/null 2>&1 && return 0
            return 1
            ;;
        claude)
            claude plugin list 2>/dev/null | grep -q "$plugin_name" && return 0
            grep -rl --include="*.json" --include="*.md" --max-count=1 "$plugin_name" "$HOME/.claude/plugins/" > /dev/null 2>&1 && return 0
            return 1
            ;;
        *)
            # Other CLIs: check generic plugin paths
            local _plugin_base
            case "$agent" in
                opencode) _plugin_base="$HOME/.config/opencode/plugins" ;;
                codex)    _plugin_base="$HOME/.codex/plugins" ;;
                mimo)     _plugin_base="$HOME/.config/mimo/plugins" ;;
                jcode)    _plugin_base="$HOME/.jcode/plugins" ;;
                *)        _plugin_base="$HOME/.${agent}/plugins" ;;
            esac
            grep -rl --include="*.json" --include="*.md" --max-count=1 "$plugin_name" "$_plugin_base/" > /dev/null 2>&1 && return 0
            return 1
            ;;
    esac
}

# Helper: check MCP configured for a SPECIFIC agent
# Usage: _check_mcp_for <agent> <mcp_name>
_check_mcp_for() {
    local agent="$1"
    local mcp_name="$2"
    case "$agent" in
        oh-my-pi)
            timeout 3 omp mcp list 2>/dev/null | grep -qi "$mcp_name" && return 0
            grep -qi "$mcp_name" "$HOME/.config/omp/mcp.json" 2>/dev/null && return 0
            # OMP shares ~/.claude.json for MCP in some setups
            grep -qi "$mcp_name" "$HOME/.claude.json" 2>/dev/null && return 0
            return 1
            ;;
        claude)
            claude mcp list 2>/dev/null | grep -qi "$mcp_name" && return 0
            grep -qi "$mcp_name" "$HOME/.claude.json" 2>/dev/null && return 0
            return 1
            ;;
        opencode)
            grep -qi "$mcp_name" "$HOME/.config/opencode/opencode.json" 2>/dev/null && return 0
            return 1
            ;;
        codex)
            grep -qi "$mcp_name" "$HOME/.codex/config.toml" 2>/dev/null && return 0
            return 1
            ;;
        *)
            local _mcp_file
            case "$agent" in
                mimo)  _mcp_file="$HOME/.config/mimo/settings.json" ;;
                jcode) _mcp_file="$HOME/.jcode/mcp.json" ;;
                *)     _mcp_file="$HOME/.${agent}/mcp.json" ;;
            esac
            grep -qi "$mcp_name" "$_mcp_file" 2>/dev/null && return 0
            return 1
            ;;
    esac
}

# Backward-compat wrappers (use primary agent)
_check_plugin() { _check_plugin_for "$_agent_type" "$1"; }
_check_mcp()    { _check_mcp_for "$_agent_type" "$1"; }

# Check if a tool is supported by a given agent
# Returns 0 (supported) or 1 (not supported)
_tool_supported_for() {
    local agent="$1"
    local tool="$2"
    case "$tool" in
        caveman|code-review)
            # Claude-only plugins
            [ "$agent" = "claude" ] && return 0
            return 1
            ;;
        context-mode|mempalace|ponytail)
            # OMP + Claude plugins
            [ "$agent" = "claude" ] && return 0
            [ "$agent" = "oh-my-pi" ] && return 0
            return 1
            ;;
        *)
            # All other tools supported by all agents (CLI binary or MCP)
            return 0
            ;;
    esac
}

echo "=========================================="
echo "  doit-skill Doctor"
echo "  Skill dirs: per detected agent"
echo "  Detected agents: $AGENT_LIST"
echo "=========================================="
echo ""

# Step 1: Check doit skill installation
echo "[1/3] Checking doit skill installation..."
CORE_FILES=("SKILL.md" "core/workflow.md" "core/execute.md" "core/iron-rules.md" "core/phase-0.md" "core/phase-1.md" "core/env-check.md" "core/e2e.md" "core/subagent.md" "core/team-roles.md")
for _agent in $AGENT_LIST; do
    _skill_dir=$(_agent_skill_dir "$_agent")
    echo "  --- Agent: $_agent ($_skill_dir) ---"
    if [ -d "$_skill_dir/doit" ]; then
        echo "  ✅ [$_agent] doit skill installed"

        missing_core=""
        for cf in "${CORE_FILES[@]}"; do
            [ ! -f "$_skill_dir/doit/$cf" ] && missing_core="$missing_core $cf"
        done
        if [ -z "$missing_core" ]; then
            echo "  ✅ [$_agent] all core files present"
        else
            echo "  ❌ [$_agent] missing core files:$missing_core"
        fi

        echo "  Checking shared phases..."
        for sf in "${SHARED_FILES[@]}"; do
            if [ -f "$_skill_dir/doit/$sf" ]; then
                echo "  ✅ [$_agent] $sf present"
            else
                echo "  ❌ [$_agent] $sf missing — re-run install"
            fi
        done

        for lnk in "${SYMLINK_TARGETS[@]}"; do
            file="${lnk%%:*}"
            target="${lnk##*:}"
            if [ -L "$_skill_dir/doit/$file" ]; then
                actual=$(readlink "$_skill_dir/doit/$file")
                if [ "$actual" = "$target" ]; then
                    echo "  ✅ [$_agent] $file -> $target (symlink OK)"
                else
                    echo "  ⚠️  [$_agent] $file -> $actual (expected $target)"
                fi
            else
                echo "  ⚠️  [$_agent] $file is not a symlink — running without shared phases"
            fi
        done
    else
        echo "  ❌ [$_agent] doit skill not installed"
        echo "  💡 Re-run: cd doit-skill && ./scripts/setup.sh --agent $_agent"
    fi
done
echo ""

# Step 2: Check bundled skills
echo "[2/3] Checking bundled skills..."
for _agent in $AGENT_LIST; do
    _skill_dir=$(_agent_skill_dir "$_agent")
    echo "  --- Agent: $_agent ($_skill_dir) ---"
    for skill in "${BUNDLED_SKILLS[@]}"; do
        if [ -d "$_skill_dir/$skill" ]; then
            echo "  ✅ [$_agent] $skill installed"
        else
            echo "  ❌ [$_agent] $skill not installed"
            echo "  💡 Re-run: cd doit-skill && ./scripts/setup.sh --agent $_agent"
        fi
    done
done
echo ""

# Step 3: Check external tools
echo "[3/3] Checking external tools..."
echo ""

# --- 3a: CLI tools (agent-independent — checked once) ---
echo "  --- CLI tools (shared across all agents) ---"
for tool in $ALL_TOOLS; do
    # Skip tools that don't have CLI binaries (agent-only)
    [[ "$tool" == "context-mode" || "$tool" == "caveman" || "$tool" == "tavily" || "$tool" == "ponytail" ]] && continue
    [[ "$tool" == "mempalace" ]] && continue  # checked separately below
    [[ "$tool" == "headroom" ]] && continue  # checked separately below
    
    if _tool_check_cached "$tool"; then
        if tools_is_critical "$tool"; then _criticality="critical"; else _criticality="optional"; fi
        echo "  $_tool_emoji ${TOOL_NAMES[$tool]} installed ($_criticality)"
    else
        if tools_is_critical "$tool"; then
            echo "  $_tool_emoji ${TOOL_NAMES[$tool]} not installed (REQUIRED)"
        else
            echo "  $_tool_emoji ${TOOL_NAMES[$tool]} not installed (optional)"
        fi
    fi
done

# mempalace CLI (agent-independent) — cache-first
if _tool_check_cached mempalace; then
    echo "  $_tool_emoji mempalace CLI installed"
else
    echo "  $_tool_emoji mempalace CLI not installed"
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

# headroom proxy check (agent-independent)
if timeout 3 curl -sf http://127.0.0.1:8787/health >/dev/null 2>&1; then
    echo "  ✅ headroom proxy running (health OK)"
else
    echo "  ℹ️  headroom proxy not running"
    echo "  💡 Deploy: headroom install apply --preset persistent-service"
fi
echo ""

# --- 3b: Per-agent plugin/MCP checks ---
for _agent in $AGENT_LIST; do
    echo "  --- Agent: $_agent ---"
    _skill_dir=$(_agent_skill_dir "$_agent")
    
    for _agent_tool in "${ALL_AGENT_TOOLS[@]}"; do
        if [[ "$_agent_tool" == "rtk" ]]; then
            # Cache-first: skip detailed check if successfully installed per cache
            if _tool_check_cached rtk 2>/dev/null; then
                echo "  $_tool_emoji ${TOOL_NAMES[rtk]} installed"
                continue
            fi
            if command -v rtk >/dev/null 2>&1 && rtk --version 2>/dev/null | head -1 | grep -q '^rtk [0-9]'; then
                echo "  ✅ ${TOOL_NAMES[rtk]} $(rtk --version 2>/dev/null | head -1)"
            elif ! command -v rtk >/dev/null 2>&1 && ! command -v 'reachingforthejack/rtk' >/dev/null 2>&1; then
                echo "  ℹ️  ${TOOL_NAMES[rtk]} not installed (optional)"
            else
                echo "  ⚠️  Wrong rtk binary detected"
            fi
            continue
        fi
        
        if [[ "$_agent_tool" == "uv" ]]; then
            if _tool_check_cached uv 2>/dev/null; then
                echo "  $_tool_emoji ${TOOL_NAMES[uv]} installed"
                continue
            fi
            if command -v uv >/dev/null 2>&1; then
                echo "  ✅ ${TOOL_NAMES[uv]} $(uv --version 2>/dev/null)"
            else
                echo "  ⚠️  ${TOOL_NAMES[uv]} not installed (degraded — Python packages unavailable)"
            fi
            continue
        fi
        
        if [[ "$_agent_tool" == "context-mode" ]]; then
            if _tool_check_cached context-mode 2>/dev/null; then
                echo "  $_tool_emoji ${TOOL_NAMES[context-mode]} installed"
                continue
            fi
            if command -v ctx >/dev/null 2>&1 && ctx --version 2>/dev/null | grep -qE '^[0-9]+\.[0-9]'; then
                echo "  ✅ ${TOOL_NAMES[context-mode]} $(ctx --version 2>/dev/null)"
            else
                echo "  ❌ ${TOOL_NAMES[context-mode]} not installed (broken — all context-mode features fail)"
                echo "  💡 Install: pip install context-mode  (requires uv)"
            fi
            continue
        fi
        
        if [[ "$_agent_tool" == "headroom" ]]; then
            if _tool_check_cached headroom 2>/dev/null; then
                echo "  $_tool_emoji ${TOOL_NAMES[headroom]} installed"
                continue
            fi
            if [[ -d "$HOME/.omp/hook" && -f "$HOME/.omp/hook/headroom.bash" ]]; then
                echo "  ✅ ${TOOL_NAMES[headroom]} installed"
            else
                echo "  ⚠️  ${TOOL_NAMES[headroom]} not installed (optional)"
                echo "  💡 Install: npm install -g headroom"
            fi
            continue
        fi
        
        if [[ "$_agent_tool" == "mempalace" ]]; then
            if _tool_check_cached mempalace 2>/dev/null; then
                echo "  $_tool_emoji ${TOOL_NAMES[mempalace]} installed"
                continue
            fi
            if command -v mempalace >/dev/null 2>&1; then
                echo "  ✅ ${TOOL_NAMES[mempalace]} CLI installed"
            else
                echo "  ⚠️  ${TOOL_NAMES[mempalace]} CLI not installed (degraded)"
                echo "  💡 Install: uv tool install mempalace"
            fi
            continue
        fi
        
        if [[ "$_agent_tool" == "codegraph" ]]; then
            if _tool_check_cached codegraph 2>/dev/null; then
                echo "  $_tool_emoji ${TOOL_NAMES[codegraph]} installed"
                continue
            fi
            _cg_found=""
            _cg_check="$WORKSPACE"
            for _cg_i in 1 2 3 4; do
                if [ -d "$_cg_check/.codegraph" ]; then
                    _cg_found="$_cg_check"
                    break
                fi
                _cg_check="$(dirname "$_cg_check")"
            done
            if [ -n "$_cg_found" ]; then
                echo "  ✅ ${TOOL_NAMES[codegraph]} initialized in $_cg_found"
            else
                echo "  ⚠️  ${TOOL_NAMES[codegraph]} not initialized (degraded — no code intelligence)"
                echo "  💡 Run: codegraph init -i"
            fi
            continue
        fi
        
        # Skip tools without agent-specific checks
        [[ "$_agent_tool" == "caveman" || "$_agent_tool" == "tavily" || "$_agent_tool" == "ponytail" ]] && continue
    done
done
echo "=========================================="
