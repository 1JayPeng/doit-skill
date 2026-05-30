# Background Process Management

Standardized patterns for running long-running commands in the background with observable exit signals.

## Core Pattern

Every background command must follow this structure:

```bash
# Create log directory
mkdir -p .scratch/logs

# Run with output capture + exit signal
(
  echo "[START] $(date '+%Y-%m-%d %H:%M:%S') — <command description>"
  <your-command-here>
  EXIT_CODE=$?
  echo "[END] $(date '+%Y-%m-%d %H:%M:%S') — exit_code=$EXIT_CODE"
  exit $EXIT_CODE
) > .scratch/logs/<name>.log 2>&1 &
BG_PID=$!
```

## Exit Signal Convention

The log file MUST contain these markers (parsed by Claude Code after process completes):

| Marker | Meaning |
|--------|---------|
| `[START]` | Process started with timestamp |
| `[END] exit_code=0` | Success |
| `[END] exit_code=N` | Failure (N != 0) |
| `[TIMEOUT]` | Process exceeded estimated runtime (set by wrapper) |

## Reading Results

After the background process completes:

```bash
# Check exit code from log
tail -1 .scratch/logs/<name>.log
# Expected: [END] 2026-05-30 12:34:56 — exit_code=0

# Read full output if needed
cat .scratch/logs/<name>.log
```

## Claude Code Integration

When using `run_in_background` parameter on Bash tool:

1. **Wrap the command** with START/END markers as shown above
2. **Set timeout** to 2x estimated runtime (default 300s if unknown)
3. **Check log file** after notification arrives — read last line for exit code
4. **Interpret result**:
   - `exit_code=0` → success, proceed to next step
   - `exit_code!=0` → failure, read log for error details, do NOT proceed

## Timeout Wrapper

For commands where you want explicit timeout handling:

```bash
(
  echo "[START] $(date '+%Y-%m-%d %H:%M:%S') — <command description>"
  timeout <seconds> <your-command-here>
  EXIT_CODE=$?
  if [ $EXIT_CODE -eq 124 ]; then
    echo "[TIMEOUT] $(date '+%Y-%m-%d %H:%M:%S') — exceeded <seconds>s"
    exit 124
  fi
  echo "[END] $(date '+%Y-%m-%d %H:%M:%S') — exit_code=$EXIT_CODE"
  exit $EXIT_CODE
) > .scratch/logs/<name>.log 2>&1 &
BG_PID=$!
```

Exit code 124 = timeout (standard `timeout` command convention).

## Per-Phase Usage

### Phase 3: Execute
- Long test suites: `cargo test --all` → `.scratch/logs/test.log`
- Build steps: `npm run build` → `.scratch/logs/build.log`

### Phase 4: E2E
- Server startup for integration tests → `.scratch/logs/e2e-server.log`
- E2E test run → `.scratch/logs/e2e-tests.log`

### Phase 7: E2E Verification Loop
- Re-run tests after simplification → `.scratch/logs/e2e-verify.log`

## Log Retention

Logs in `.scratch/logs/` are cleaned up in Phase 9 along with the `.scratch/` directory.

## When NOT to Use Background

- Commands expected to complete in <10 seconds → run foreground
- Interactive commands (requires user input) → run foreground
- Commands with unclear exit conditions → run foreground with explicit timeout
- Sequential dependencies (B needs A's output) → run sequentially in foreground
