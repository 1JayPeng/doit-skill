# Phase 3: Execute

## Rules

- **uv virtualenv for all Python code.** Create/activate with `uv venv` + `source .venv/bin/activate`. Every Python command runs through uv.
- **RTK for all shell commands.** RTK auto-wraps via PreToolUse hook. Use `rtk` prefix for manual calls.
  - `rtk gain` — token savings analytics
  - `rtk gain --history` — command history with savings
  - `rtk discover` — missed optimization opportunities
  - `rtk proxy <cmd>` — bypass RTK filter (debug only)
- **Context-Mode for context management.** Auto-indexes command output, provides semantic search.
  - `ctx_execute` — run commands, output auto-indexed
  - `ctx_execute_file` — process large files without loading into context
  - `ctx_search` — search previously indexed content
  - `ctx_batch_execute` — run multiple commands, search results together
- **Vertical slice TDD.** One REQ at a time. RED -> GREEN -> REFACTOR. No horizontal slicing.
- **Logging rules:**
  - Entry function: log inputs
  - Exit function: log result
  - Exception: traceback + context (user, operation, data state)
  - Default level WARNING. `--verbose` -> DEBUG

## TDD Loop per REQ

### CONTEXT (before RED)
Before writing tests, understand the code you'll modify:
1. `codegraph_context` — get focused context for the REQ task (start here)
2. `codegraph_search` — if you need a specific symbol name
3. `codegraph_node` — if you need a function signature from tests
4. `ctx_search` — look up previously indexed information from this session

### RED
Write test for REQ-N behavior. Test through public interface, not internals.
```
FAIL: test_xxx for REQ-00X
```
If you don't know what test to write, go back to spec. Don't guess.

### GREEN
Implement minimum code to pass test. No extra logic.
```
PASS: test_xxx for REQ-00X
```

### REFACTOR
Merge duplicate code with existing code. Minimal change. No architectural restructuring (that's Phase 5).

### REVIEW + SIMPLIFY (MANDATORY after each REQ)
After RED→GREEN→REFACTOR completes, **before moving to next REQ**:
1. **Read what you wrote** — read the full context of changes, not just the diff
2. **Simplify** — remove dead imports, flatten unnecessary abstractions, combine redundant loops
3. **Check documentation** — does README/CLAUDE.md need updating?
4. **Verify** — tests still pass after simplifying

**Do not skip this.** Do not move to next REQ without reviewing current changes.

**Full Phase 6 review-simplify runs after Phase 5.**

### Test Execution

Use `ctx_execute` for running tests — output auto-indexed for search:
- `ctx_execute` — run test commands, search results with `ctx_search`
- `ctx_batch_execute` — run multiple test commands, search all output together

**Full Phase 6 review-simplify runs after Phase 5.**

### Spec Alignment Check (Interactive)

After each REQ completes:
```
REQ-00X DONE. Spec says: "user can do X". Current coverage:
  [x] user can do X with valid input
  [ ] user can do X with edge case Y
Proceed to REQ-00(X+1)? (yes/no, or describe gap)
```

**Wait for user. Don't proceed until confirmed.**

### State Tracking

Update `.spec/current.md` status as REQs complete. Save runtime state to `.scratch/workflow-state.json`. Workflow state includes current phase so `/doit` can resume mid-session.
