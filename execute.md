# Phase 3: Execute

## Rules

- **uv virtualenv for all Python code.** Create/activate with `uv venv` + `source .venv/bin/activate`. Every Python command runs through uv.
  - **Fallback:** If uv not available -> use `pip` + `python3 -m venv .venv` + `source .venv/bin/activate`.
- **RTK for all shell commands.** RTK auto-wraps via PreToolUse hook. Use `rtk` prefix for manual calls.
  - `rtk gain` — token savings analytics
  - `rtk gain --history` — command history with savings
  - `rtk discover` — missed optimization opportunities
  - `rtk proxy <cmd>` — bypass RTK filter (debug only)
  - **Fallback:** If RTK not available -> run Bash commands directly (no token optimization).
- **Context-Mode for context management.** Auto-indexes command output, provides semantic search.
  - `ctx_execute` — run commands, output auto-indexed
  - `ctx_execute_file` — process large files without loading into context
  - `ctx_search` — search previously indexed content
  - `ctx_batch_execute` — run multiple commands, search results together
  - **Fallback:** If Context-Mode not installed ->
    - `ctx_execute` -> native Bash tool (output not indexed)
    - `ctx_execute_file` -> `Read` tool (loads file into context)
    - `ctx_search` -> `grep`/`find` with `Agent Explore`
    - `ctx_batch_execute` -> parallel Bash calls + `Agent Explore`
- **Vertical slice TDD.** One REQ at a time. RED -> GREEN -> REFACTOR. No horizontal slicing.
- **Logging rules:**
  - Entry function: log inputs
  - Exit function: log result
  - Exception: traceback + context (user, operation, data state)
  - Default level WARNING. `--verbose` -> DEBUG

## TDD Loop per REQ

### CONTEXT (before RED)
Before writing tests, understand the code you'll modify:
1. `tokensave_context` — get focused context for the REQ task (start here)
   - **Fallback:** If TokenSave unavailable -> `Agent Explore` with task description
2. `tokensave_search` — find specific symbols by name
   - **Fallback:** If TokenSave unavailable -> `grep -rn` + `find`
3. `tokensave_node` — function signature, full source from tests
   - **Fallback:** If TokenSave unavailable -> `Read` the specific file
4. `tokensave_callers` / `tokensave_callees` — call graph edges, blast radius
5. `tokensave_impact` — what's affected by changing a symbol
6. `tokensave_files` — understand project file structure
7. `ctx_search` — look up previously indexed information from this session
   - **Fallback:** If Context-Mode unavailable -> `grep` command output

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
After RED->GREEN->REFACTOR completes, **before moving to next REQ**:
1. **tokensave scan** — `tokensave_simplify_scan(files=[<changed_files>])` — auto-detect duplications, dead code, complexity
2. **Read what you wrote** — read the full context of changes, not just the diff
3. **Simplify** — remove dead imports, flatten unnecessary abstractions, combine redundant loops
4. **Check documentation** — does README/CLAUDE.md need updating?
5. **Verify** — tests still pass after simplifying

**Do not skip this.** Do not move to next REQ without reviewing current changes.

**Full Phase 6 review-simplify runs after Phase 5.** Shared source: [shared/review-simplify.md](shared/review-simplify.md)

**Full Phase 4 e2e + Phase 7 e2e verification runs after Phase 6.** Shared source: [shared/e2e-verify.md](shared/e2e-verify.md)

### Test Execution

Use `ctx_execute` for running tests — output auto-indexed for search:
- `ctx_execute` — run test commands, search results with `ctx_search`
- `ctx_batch_execute` — run multiple test commands, search all output together
- **Fallback:** If Context-Mode unavailable -> run tests via native Bash. Output printed to context (more tokens used).

### Spec Alignment Check (Interactive)

After each REQ completes:
```
REQ-00X DONE. Spec says: "user can do X". Current coverage:
  [x] user can do X with valid input
  [ ] user can do X with edge case Y
Proceed to REQ-00(X+1)? (yes/no, or describe gap)
```

**Wait for user. After user confirms "yes":**
- More REQs remaining → go to REQ-00(X+1)
- This was the last REQ → proceed to Phase 4 (E2E)

### State Tracking

Update `.spec/current.md` status as REQs complete. Save runtime state to `.scratch/workflow-state.json`. Workflow state includes current phase so `/doit` can resume mid-session.

## Phase 3 End

**When ALL REQs are done: proceed to Phase 4 (E2E). Code changes are NOT the end of the session.**

Full phase flow: Phase 4 → Phase 5 → Phase 6 → Phase 7 → Phase 8 (commit + push). Every phase runs. See SKILL.md Phase Gate Checklist.
