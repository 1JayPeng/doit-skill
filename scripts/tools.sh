#!/usr/bin/env bash
# tools.sh — Bash-sourceable tool registry for doit-skill
# Source this file to get access to install/verify/version for each tool.
# Used by: setup.sh, doctor.sh

# Tool IDs
ALL_TOOLS="rtk uv context-mode caveman mempalace headroom tavily codegraph ponytail"
CRITICAL_TOOLS="context-mode caveman mempalace headroom codegraph"
OPTIONAL_TOOLS="rtk uv tavily ponytail"

# Tool metadata (name, critical, fallback, addon, skip_flag)
declare -A TOOL_NAMES TOOL_CRITICAL TOOL_FALLBACK TOOL_ADDONS TOOL_SKIP_FLAGS

# Initialize metadata
_tool_init_metadata() {
  TOOL_NAMES=(
    [rtk]="RTK (Rust Token Killer)"
    [uv]="uv (Python package manager)"
    [context-mode]="context-mode"
    [caveman]="caveman (Token compression)"
    [mempalace]="MemPalace (Memory system)"
    [headroom]="headroom (Context compression)"
    [tavily]="Tavily (Web search)"
    [codegraph]="CodeGraph (Code intelligence)"
    [ponytail]="ponytail (Dev tool)"
  )
  
  TOOL_CRITICAL=(
    [rtk]=false
    [uv]=false
    [context-mode]=true
    [caveman]=true
    [mempalace]=true
    [headroom]=true
    [codegraph]=true
    [ponytail]=false
  )
  
  TOOL_FALLBACK=(
    [rtk]="skip"
    [uv]="degraded"
    [context-mode]="degraded"
    [caveman]="skip"
    [mempalace]="degraded"
    [headroom]="skip"
    [tavily]="skip"
    [codegraph]="degraded"
    [ponytail]="skip"
  )
  TOOL_ADDONS=(
    [context-mode]="context-mode"
    [caveman]="caveman"
    [mempalace]="mempalace"
    [headroom]="headroom"
    [codegraph]="codegraph"
    [tavily]="tavily"
    [ponytail]="ponytail"
  )
  
  TOOL_SKIP_FLAGS=(
    [rtk]="--skip-updates"
    [uv]="--skip-optional"
    [context-mode]="--skip-optional"
    [caveman]="--skip-optional"
    [mempalace]="--skip-optional"
    [headroom]="--skip-optional"
    [tavily]="--skip-optional"
    [codegraph]="--skip-optional"
    [ponytail]="--skip-optional"
  )
}
_tool_init_metadata

# Source installer scripts
SCRIPT_DIR_INSTALLERS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/installers"

for _installer in "$SCRIPT_DIR_INSTALLERS"/install_*.sh; do
  [ -f "$_installer" ] && source "$_installer"
done

# Check if tool should be skipped due to CLI flags
# Usage: _tool_should_skip <tool_id> [--skip-optional] [--skip-updates]
_tool_should_skip() {
  local tool_id="$1"
  shift
  for arg in "$@"; do
    case "$arg" in
      --skip-optional)
        [[ "${TOOL_CRITICAL[$tool_id]}" == "false" ]] && return 0 ;;
      --skip-updates)
        [[ "$tool_id" == "rtk" ]] && return 0 ;;
    esac
  done
  return 1
}

# Check if a tool is critical
tools_is_critical() {
  [[ "${TOOL_CRITICAL[$1]}" == "true" ]]
}

# Get fallback behavior
tools_fallback() {
  echo "${TOOL_FALLBACK[$1]:-skip}"
}

# Map cache status to display emoji
_tool_emoji() {
  case "$1" in
    ok) echo "✅" ;;
    fail|missing) echo "❌" ;;
    degraded) echo "⚠️" ;;
    *) echo "❓" ;;
  esac
}

# Cache-first tool check. Tries cache, falls back to command -v.
# Sets _tool_status, _tool_emoji. Returns 0 = ok, 1 = not installed.
_tool_check_cached() {
  local tool_id="$1"
  local cached
  cached=$(tools_read_status "$tool_id" 2>/dev/null)

  if [ "$cached" = "ok" ]; then
    _tool_status="ok"
    _tool_emoji="$(_tool_emoji ok)"
    return 0
  fi

  # Cache miss or fail — fall back to live check
  if command -v "$tool_id" >/dev/null 2>&1; then
    _tool_status="ok"
    _tool_emoji="$(_tool_emoji ok)"
    return 0
  fi

  _tool_status="${cached:-missing}"
  _tool_emoji="$(_tool_emoji "$_tool_status")"
  return 1
}

# Save tool status to cache file
TOOLS_CACHE="${TOOLS_CACHE:-.doit/env-cache.json}"
tools_save_status() {
  local tool_id="$1" status="$2" message="${3:-}"
  local tmp="$TOOLS_CACHE.tmp.$$"
  mkdir -p "$(dirname "$TOOLS_CACHE")"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "
import json, os, time
f = '$TOOLS_CACHE'
data = {}
if os.path.exists(f):
    with open(f) as fh: data = json.load(fh)
data.setdefault('tools', {})['$tool_id'] = {
    'status': '$status', 'lastChecked': int(time.time()), 'message': '$message'
}
with open(f, 'w') as fh: json.dump(data, fh, indent=2)
" 2>/dev/null
  fi
}

# Read tool status from cache
tools_read_status() {
  local tool_id="$1"
  if [ -f "$TOOLS_CACHE" ] && command -v python3 >/dev/null 2>&1; then
    python3 -c "
import json
with open('$TOOLS_CACHE') as f: data = json.load(f)
s = data.get('tools', {}).get('$tool_id', {}).get('status', 'unknown')
print(s)
" 2>/dev/null
  else
    echo "unknown"
  fi
}
