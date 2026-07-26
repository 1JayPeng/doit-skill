#!/usr/bin/env bash
# Regression check: oh-my-pi command install path
# Asserts OMP command copies exist and match root commands/doit.md
# Asserts root/runtime setup.sh define OMP command dirs and OMP_SESSION_ID

set -euo pipefail

# Resolve repo root from script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

ROOT_CMD="commands/doit.md"
COMMAND_COPIES=(".omp/commands/doit.md" ".omp/skills/doit/commands/doit.md")
SETUP_FILES=("scripts/setup.sh" ".omp/skills/doit/scripts/setup.sh")

[ -f "$ROOT_CMD" ] || { echo "error: root command file missing: $ROOT_CMD"; exit 1; }

for cmd in "${COMMAND_COPIES[@]}"; do
  [ -f "$cmd" ] || { echo "error: OMP command file missing: $cmd"; exit 1; }
done

python3 - "$ROOT_CMD" "${COMMAND_COPIES[@]}" <<'PY'
import sys
from pathlib import Path

root_path = sys.argv[1]
root = Path(root_path).read_bytes()
for cmd_path in sys.argv[2:]:
    if Path(cmd_path).read_bytes() != root:
        print(f"error: command files differ: {root_path} vs {cmd_path}")
        raise SystemExit(1)
PY

for setup in "${SETUP_FILES[@]}"; do
  [ -f "$setup" ] || { echo "error: setup file missing: $setup"; exit 1; }

  if ! awk '/^[[:space:]]*oh-my-pi\)/,/^[[:space:]]*;;/ { if ($0 == "      COMMANDS_DIR=\".omp/commands\"") found=1 } END { exit !found }' "$setup"; then
    echo "error: $setup oh-my-pi case missing COMMANDS_DIR=\".omp/commands\""
    exit 1
  fi

  if ! awk '/^[[:space:]]*oh-my-pi\)/,/^[[:space:]]*;;/ { if ($0 == "      GLOBAL_COMMANDS_DIR=\"$HOME/.omp/agent/commands\"") found=1 } END { exit !found }' "$setup"; then
    echo "error: $setup oh-my-pi case missing GLOBAL_COMMANDS_DIR=\"\$HOME/.omp/agent/commands\""
    exit 1
  fi

  if ! grep -q 'OMP_SESSION_ID' "$setup"; then
    echo "error: $setup missing OMP_SESSION_ID export"
    exit 1
  fi
done

echo "ok"