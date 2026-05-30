# Background Process Management

Standardized patterns for running long-running commands with observable exit signals, automatic monitoring, and phase-continuation.

## Three Tiers

| Tier | When | Mechanism |
|------|------|-----------|
| **Foreground** | <10s, simple commands | Direct Bash call |
| **Background** | 10s-5min, no interactive need | Shell `&` + log file + `[START]`/`[END]` markers |
| **Tmux + Monitor** | >5min, multi-phase, or needs auto-continuation | Named tmux session + Claude Code monitor + auto-resume |

## Tier 1: Foreground

Simple commands, run directly:
```bash
cargo check
pytest tests/unit/
```

## Tier 2: Background (Log File)

For commands that take 10s-5min, run in background with log markers:

```bash
mkdir -p .scratch/logs
(
  echo "[START] $(date '+%Y-%m-%d %H:%M:%S') — <command description>"
  <your-command-here>
  EXIT_CODE=$?
  echo "[END] $(date '+%Y-%m-%d %H:%M:%S') — exit_code=$EXIT_CODE"
  exit $EXIT_CODE
) > .scratch/logs/<name>.log 2>&1 &
BG_PID=$!
```

Check results:
```bash
tail -1 .scratch/logs/<name>.log
# Expected: [END] 2026-05-30 12:34:56 — exit_code=0
```

## Tier 3: Tmux + Monitor (Auto-Resume)

For long-running tasks (>5min) where Claude Code should automatically continue to the next phase when the task completes.

### Core Concept

1. Launch a long task in a **named tmux session**
2. Set up a **Claude Code monitor** that watches for the task's completion marker
3. When the monitor fires, Claude Code reads the log, checks the exit code, and **automatically proceeds to the next phase**
4. No human intervention needed

### Setup

```bash
# Create log directory
mkdir -p .scratch/logs

# Create named tmux session (detached)
TMUX_SESSION="doit-<phase-name>"
tmux new-session -d -s "$TMUX_SESSION"

# Send the long-running command to tmux
tmux send-keys -t "$TMUX_SESSION" '(
  echo "[START] $(date "+%Y-%m-%d %H:%M:%S") — <description>"
  <your-long-command-here>
  EXIT_CODE=$?
  echo "[END] $(date "+%Y-%m-%d %H:%M:%S") — exit_code=$EXIT_CODE"
  exit $EXIT_CODE
) > .scratch/logs/<name>.log 2>&1' Enter
```

### Monitor Setup

After launching the tmux session, set up a monitor to watch for completion:

```bash
# Monitor watches for [END] marker in the log file
Monitor "Watch <phase> completion" \
  "grep -q '\[END\]' .scratch/logs/<name>.log" \
  --interval 10
```

The monitor runs every 10 seconds. When `[END]` appears in the log, Claude Code receives a notification.

### Monitor Callback (Auto-Resume)

When the monitor fires:

1. **Read the log's last line** to get exit code:
   ```bash
   tail -1 .scratch/logs/<name>.log
   ```

2. **Interpret result**:
   - `exit_code=0` → Success. Proceed to next phase.
   - `exit_code!=0` → Failure. Read log for error details, decide next action.
   - `[TIMEOUT]` → Task exceeded time limit. Investigate.

3. **Clean up tmux session**:
   ```bash
   tmux kill-session -t "doit-<phase-name>"
   ```

4. **Continue workflow** — execute the next phase automatically.

### Progress Reporting (User Visibility)

Long-running tasks should give users a sense of control. Add `[PROGRESS]` markers to the task log, and report progress when monitor checks but task isn't complete yet.

**In the task script, emit progress markers:**

```bash
tmux send-keys -t "$TMUX_SESSION" '(
  echo "[START] $(date "+%Y-%m-%d %H:%M:%S") — cargo build --release"

  echo "[PROGRESS] 0% — Starting build..."
  cargo build --release 2>&1 | while IFS= read -r line; do
    echo "$line"
  done
  EXIT_CODE=$?

  echo "[PROGRESS] 100% — Build complete, exit_code=$EXIT_CODE"
  echo "[END] $(date "+%Y-%m-%d %H:%M:%S") — exit_code=$EXIT_CODE"
  exit $EXIT_CODE
) > .scratch/logs/build.log 2>&1' Enter
```

**For tasks without natural progress (e.g., compiler, test runner), use elapsed time:**

```bash
tmux send-keys -t "$TMUX_SESSION" '(
  START_TIME=$(date +%s)
  echo "[START] $(date "+%Y-%m-%d %H:%M:%S") — cargo test --all"

  # Progress reporter runs in background
  (
    while true; do
      ELAPSED=$(( $(date +%s) - START_TIME ))
      if [ $ELAPSED -eq 60 ]; then
        echo "[PROGRESS] 1min elapsed — tests still running..."
      elif [ $ELAPSED -eq 180 ]; then
        echo "[PROGRESS] 3min elapsed — tests still running..."
      elif [ $ELAPSED -eq 300 ]; then
        echo "[PROGRESS] 5min elapsed — tests still running..."
      fi
      sleep 30
    done
  ) &
  PROGRESS_PID=$!

  cargo test --all
  EXIT_CODE=$?

  kill $PROGRESS_PID 2>/dev/null || true

  TOTAL_ELAPSED=$(( $(date +%s) - START_TIME ))
  echo "[PROGRESS] Complete in $TOTAL_ELAPSED seconds"
  echo "[END] $(date "+%Y-%m-%d %H:%M:%S") — exit_code=$EXIT_CODE"
  exit $EXIT_CODE
) > .scratch/logs/test.log 2>&1' Enter
```

**When Claude Code monitor checks and task is NOT yet complete, report progress:**

```bash
# Monitor check script — reports progress if still running
if grep -q '\[END\]' .scratch/logs/<name>.log; then
  # Task complete — handle normally
  tail -1 .scratch/logs/<name>.log
else
  # Task still running — report latest progress
  LATEST_PROGRESS=$(grep '\[PROGRESS\]' .scratch/logs/<name>.log | tail -1)
  if [ -n "$LATEST_PROGRESS" ]; then
    echo "Still running: $LATEST_PROGRESS"
  fi
fi
```

**Progress reporting to user — keep it brief:**

When monitor fires but task still running, show user:
```
⏳ <task-name> still running...
  Latest: "[PROGRESS] 3min elapsed — tests still running..."
  Started: 14:32:05
```

When task completes, show:
```
✅ <task-name> complete!
  Duration: 4m 23s
  Exit: 0 (success)
  → Proceeding to Phase N
```

**Progress marker convention:**

| Marker | When to use |
|--------|-------------|
| `[PROGRESS] 0%` | Task just started |
| `[PROGRESS] Xmin elapsed` | Time-based checkpoint (every 1-3 min) |
| `[PROGRESS] Step N/M` | Multi-step task (e.g., "Step 2/4 — compiling tests") |
| `[PROGRESS] 100%` | Task finishing, before `[END]` |

**Rule: Only report progress if user can see it.** If the monitor interval is short (<30s), don't report every check — only on first check after a new `[PROGRESS]` marker appears. Avoid spam.

### Complete Example: Phase 3 Execute (Long Build)

```bash
# Step 1: Launch in tmux
mkdir -p .scratch/logs
TMUX_SESSION="doit-build"
tmux new-session -d -s "$TMUX_SESSION"
tmux send-keys -t "$TMUX_SESSION" '(
  echo "[START] $(date "+%Y-%m-%d %H:%M:%S") — cargo build --release"
  cargo build --release
  EXIT_CODE=$?
  echo "[END] $(date "+%Y-%m-%d %H:%M:%S") — exit_code=$EXIT_CODE"
  exit $EXIT_CODE
) > .scratch/logs/build.log 2>&1' Enter

# Step 2: Set up monitor
Monitor "Watch build completion" \
  "grep -q '\[END\]' .scratch/logs/build.log" \
  --interval 15

# Claude Code continues with other work while waiting...
# When monitor fires:
#   - tail -1 .scratch/logs/build.log → check exit_code
#   - If 0: proceed to Phase 4 (E2E)
#   - If !=0: read log, diagnose, fix
```

### Complete Example: Phase 4 E2E (Long Test Suite)

```bash
# Step 1: Launch E2E server + tests in tmux
mkdir -p .scratch/logs
tmux new-session -d -s "doit-e2e"

# Start server in tmux pane 0
tmux send-keys -t "doit-e2e:0" '(
  echo "[START] $(date "+%Y-%m-%d %H:%M:%S") — E2E dev server"
  uv run python -m uvicorn main:app --host 127.0.0.1 --port 8765
  EXIT_CODE=$?
  echo "[END] $(date "+%Y-%m-%d %H:%M:%S") — exit_code=$EXIT_CODE"
  exit $EXIT_CODE
) > .scratch/logs/e2e-server.log 2>&1' Enter

# Split window, run tests in pane 1
tmux split-window -t "doit-e2e" -h
tmux send-keys -t "doit-e2e:1" 'sleep 10 && (
  echo "[START] $(date "+%Y-%m-%d %H:%M:%S") — E2E test suite"
  uv run pytest tests/e2e/ -v --tb=short
  EXIT_CODE=$?
  echo "[END] $(date "+%Y-%m-%d %H:%M:%S") — exit_code=$EXIT_CODE"
  exit $EXIT_CODE
) > .scratch/logs/e2e-tests.log 2>&1' Enter

# Step 2: Monitor test completion
Monitor "Watch E2E test completion" \
  "grep -q '\[END\]' .scratch/logs/e2e-tests.log" \
  --interval 20
```

### Multi-Phase Pipeline

For tasks that chain multiple phases sequentially:

```bash
# Phase A: Build
tmux new-session -d -s "doit-pipeline"
tmux send-keys -t "doit-pipeline" '(
  echo "[START] $(date "+%Y-%m-%d %H:%M:%S") — Phase A: Build"
  cargo build --release
  EXIT_A=$?
  echo "[END] $(date "+%Y-%m-%d %H:%M:%S") — exit_code=$EXIT_A"

  echo "[START] $(date "+%Y-%m-%d %H:%M:%S") — Phase B: Test"
  cargo test --all
  EXIT_B=$?
  echo "[END] $(date "+%Y-%m-%d %H:%M:%S") — exit_code=$EXIT_B"

  # Final: overall result
  echo "[PIPELINE_DONE] exit_code=$((EXIT_A | EXIT_B))"
  exit $((EXIT_A | EXIT_B))
) > .scratch/logs/pipeline.log 2>&1' Enter

# Monitor for pipeline completion
Monitor "Watch pipeline completion" \
  "grep -q '\[PIPELINE_DONE\]' .scratch/logs/pipeline.log" \
  --interval 30
```

### Exit Signal Convention

| Marker | Meaning |
|--------|---------|
| `[START]` | Phase started with timestamp |
| `[PROGRESS]` | Intermediate progress update (for user visibility) |
| `[END] exit_code=0` | Success |
| `[END] exit_code=N` | Failure (N != 0) |
| `[TIMEOUT]` | Exceeded estimated runtime |
| `[PIPELINE_DONE]` | Multi-phase pipeline completed |

### Timeout Wrapper

For commands where you want explicit timeout handling:

```bash
tmux send-keys -t "$TMUX_SESSION" '(
  echo "[START] $(date "+%Y-%m-%d %H:%M:%S") — <description>"
  timeout <seconds> <your-command-here>
  EXIT_CODE=$?
  if [ $EXIT_CODE -eq 124 ]; then
    echo "[TIMEOUT] $(date "+%Y-%m-%d %H:%M:%S") — exceeded <seconds>s"
    exit 124
  fi
  echo "[END] $(date "+%Y-%m-%d %H:%M:%S") — exit_code=$EXIT_CODE"
  exit $EXIT_CODE
) > .scratch/logs/<name>.log 2>&1' Enter
```

### Tmux Session Management

```bash
# List active doit sessions
tmux list-sessions | grep doit-

# Check session status
tmux has-session -t "doit-<name>" 2>/dev/null && echo "running" || echo "done"

# Kill session when done
tmux kill-session -t "doit-<name>" 2>/dev/null || true

# Send-keys to running session (e.g., interrupt)
tmux send-keys -t "doit-<name>" C-c
```

### Per-Phase Usage

| Phase | Long Task | Tmux Session | Monitor |
|-------|-----------|-------------|---------|
| Phase 3 | `cargo build --release` | `doit-build` | `[END]` in build.log |
| Phase 4 | E2E server + test suite | `doit-e2e` | `[END]` in e2e-tests.log |
| Phase 7 | Re-run E2E after simplify | `doit-e2e-verify` | `[END]` in e2e-verify.log |
| Phase 8 | Large commit + push | `doit-commit` | `[END]` in commit.log |

### When to Use Each Tier

| Condition | Tier |
|-----------|------|
| <10s, simple | Foreground |
| 10s-5min, single command | Background (log file) |
| >5min, single command | Tmux + Monitor |
| Multi-phase pipeline | Tmux + Monitor |
| Needs auto-continuation | Tmux + Monitor |
| Interactive (needs user input) | Foreground |
| Sequential deps (B needs A output) | Tmux pipeline or foreground |

### Log Retention

Logs in `.scratch/logs/` are cleaned up in Phase 9 along with the `.scratch/` directory.

### Fallback: No Tmux

If tmux is not available:
1. Use Tier 2 (Background with log file)
2. Use `Bash run_in_background=true` with timeout
3. Check log file after notification

```bash
# Fallback: no tmux, use shell background
(
  echo "[START] $(date '+%Y-%m-%d %H:%M:%S') — <description>"
  <command>
  EXIT_CODE=$?
  echo "[END] $(date '+%Y-%m-%d %H:%M:%S') — exit_code=$EXIT_CODE"
  exit $EXIT_CODE
) > .scratch/logs/<name>.log 2>&1 &

# Monitor the log file
Monitor "Watch <name> completion" \
  "grep -q '\[END\]' .scratch/logs/<name>.log" \
  --interval 10
```

### Claude Code Monitor Behavior

When a monitor fires:
1. Claude Code receives a "Monitor event" notification
2. It reads the relevant log file
3. It checks the exit code
4. **If success** → automatically continues to the next workflow phase
5. **If failure** → reads the log for diagnostics, decides on remediation
6. The user sees "● 正常，继续跑。" or "Monitor event: <description>"

This enables fully autonomous long-running workflows without human intervention.
