# Phase 3: Execute

## Rules

- **uv virtualenv for all Python code.** Create/activate with `uv venv` + `source .venv/bin/activate`. Every Python command runs through uv.
  - **Fallback:** If uv not available -> use `pip` + `python3 -m venv .venv` + `source .venv/bin/activate`.
- **RTK for all shell commands.** RTK auto-wraps via PreToolUse hook. All shell commands in this phase go through RTK for 60-90% token savings.
  - `rtk gain` — token savings analytics (run after Phase 3 completes)
  - `rtk gain --history` — command history with per-command savings
  - `rtk discover` — scan conversation history for missed optimization opportunities (run in Phase 6)
  - `rtk proxy <cmd>` — bypass RTK filter (debug only)
  - **Fallback:** If RTK not available -> run Bash commands directly (no token optimization).
- **RTK wraps all phases.** RTK is not Phase 3 only — it auto-wraps every Bash call via PreToolUse hook across the entire session.

- **Context-Mode for context management.** Auto-indexes command output, provides semantic search.
  - `ctx_execute` — run commands, output auto-indexed
  - `ctx_execute_file` — process large files without loading into context
  - `ctx_search` — search previously indexed content
  - `ctx_batch_execute` — run multiple commands, search results together
  - **Fallback:** If Context-Mode not installed ->
    - `ctx_execute` -> native Bash tool (output not indexed)
    - `ctx_execute_file` -> `Read` tool (loads file into context)
    - `ctx_search` -> `grep`/`find` with `Agent general-purpose`
    - `ctx_batch_execute` -> parallel Bash calls + `Agent general-purpose`
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
   - **Fallback:** If TokenSave unavailable -> `Agent general-purpose` with task description
2. `tokensave_search` — find specific symbols by name
   - **Fallback:** If TokenSave unavailable -> `grep -rn` + `find`
3. `tokensave_similar(symbol="<name>")` — find symbols with similar names (avoid naming inconsistency)
4. `tokensave_node` — function signature, full source from tests
   - **Fallback:** If TokenSave unavailable -> `Read` the specific file
5. `tokensave_body(symbol="<name>")` — return full source body of a symbol (faster than node lookup)
6. `tokensave_signature(qualified_name="<name>")` — get function signature without body (visibility, generics, params, return type)
7. `tokensave_signature_search(params="&mut self", returns="Result")` — find functions by signature shape (refactoring: find similar patterns)
8. `tokensave_callers` / `tokensave_callees` — call graph edges, blast radius
9. `tokensave_impact` — what's affected by changing a symbol
10. `tokensave_files` — understand project file structure
11. `tokensave_test_map(node_id="<id>")` — find test coverage for symbol being modified
12. `tokensave_affected_tests(files=[<changed_files>])` — find test files affected by changed source files
13. `tokensave_diagnostics(scope="workspace")` — run type-checker (cargo check / tsc / pyright) before writing code
14. `ctx_search` — look up previously indexed information from this session
    - **Fallback:** If Context-Mode unavailable -> `grep` command output
15. `mempalace_search query="<REQ description>" wing="<project>" limit=2` — recover cross-session context from prior implementations
16. `mempalace_get_drawer drawer_id="<id from search>"` — fetch full content of a specific drawer (when search preview is insufficient)
17. `mempalace_list_drawers wing="<project>" room="implementation" limit=5` — browse recent implementation notes
    - **Fallback:** If MemPalace unavailable -> skip (tokensave + context-mode cover session-level context)

### IMPLEMENT — Reuse Gate (MANDATORY before writing any code)

**Before writing ANY code, check for existing reusable code.** This is the primary gate — don't defer to review/simplify.

1. **tokensave_search** — search for functions/utilities that already do what you need:
   - `tokensave_search(query="<functionality needed>")` — find existing implementations
   - `tokensave_signature_search(params="<key param>", returns="<return type>")` — find functions by shape
2. **tokensave_similar** — check if a similar function already exists:
   - `tokensave_similar(symbol="<new_function_name>")` — find naming conflicts or near-duplicates
3. **mempalace_search** — check cross-session memory for prior solutions:
   - `mempalace_search query="<feature>" wing="<project>" limit=3` — find related implementations
4. **Decision:** If existing code can be reused or extended → **reuse it**. Only write new code if nothing fits.

**Rule: Write code ONCE. If it already exists, use it. If it's close, adapt it. Review/Simplify catches what this misses — but this gate should catch 90%.**

### IMPLEMENT (edit primitives for code changes)

Use tokensave edit primitives instead of Read+Edit when modifying source files — they trigger in-place re-index so the graph never goes stale:
- `tokensave_str_replace` — replace a unique string; fails if 0 or >1 matches (safe single-edit)
- `tokensave_multi_str_replace` — apply N replacements atomically (all-or-nothing transaction)
- `tokensave_insert_at` — insert content before/after an anchor string or line number
- `tokensave_ast_grep_rewrite` — structural code rewrite via ast-grep CLI (refactoring, renaming)
- **Fallback:** If TokenSave unavailable -> native Read + Edit tools

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
2. **tokensave_similar** — `tokensave_similar(symbol="<new_function_name>")` — check if a similarly named symbol already exists (naming inconsistency)
3. **Read what you wrote** — read the full context of changes, not just the diff
4. **Simplify** — remove dead imports, flatten unnecessary abstractions, combine redundant loops
5. **Check documentation** — does README/CLAUDE.md need updating?
6. **Verify** — tests still pass after simplifying

**Do not skip this.** Do not move to next REQ without reviewing current changes.

**Full Phase 6 review-simplify runs after Phase 5.** Shared source: [shared/review-simplify.md](shared/review-simplify.md)

**Full Phase 4 e2e + Phase 7 e2e verification runs after Phase 6.** Shared source: [shared/e2e-verify.md](shared/e2e-verify.md)

### Test Execution

Run only affected tests when possible — skip full suite for small changes:

**Primary (fast path):**
- `tokensave_affected_tests(files=[<changed_files>])` — find test files affected by changed source files
- `tokensave_run_affected_tests(changed_paths=[<changed_files>])` — run only affected tests (cargo test)
- For non-Rust projects: use `ctx_execute` with affected test files

**Fallback (full suite):**
- `ctx_execute` — run all test commands, search results with `ctx_search`
- `ctx_batch_execute` — run multiple test commands, search all output together
- **Context-Mode unavailable:** run tests via native Bash. Output printed to context (more tokens used).

### Spec Alignment Check (Non-Interruptive)

After each REQ completes, present alignment report:
```
REQ-00X DONE. Spec says: "user can do X". Current coverage:
  [x] user can do X with valid input
  [ ] user can do X with edge case Y
```

**铁律: Use AskUserQuestion, never stop and wait.**

```
AskUserQuestion:
  question: "REQ-00X complete. Proceed to next REQ?"
  header: "REQ-00X"
  options:
    - label: "Yes, continue (Recommended)"
      description: "Proceed to REQ-00(X+1)"
    - label: "Gap found"
      description: "Describe gap between spec and implementation"
```

**If user selects "Yes" or doesn't answer:** proceed to next REQ or Phase 4 (E2E) if last REQ.
**If user describes gap:** fix it, then continue.

### State Tracking

Update `.spec/current.md` status as REQs complete. Cross-session resume uses git branch, commit history, spec REQ statuses, and MemPalace (if available).

After each REQ completes, if MemPalace is active:
```
mempalace_add_drawer wing="<project>" room="implementation" content="REQ-00X: <what was done, key files changed>"
```

### Background Process Management (铁律)

**铁律: 长时间任务必须后台执行 + 轮询。不允许空等。** See [principles.md](principles.md) Principle 0.5.
**铁律: 所有代码变更必须提交并推送。没有例外。** See [principles.md](principles.md) Principle 1.

For long-running commands, use the three-tier approach from [background-process.md](background-process.md):

**Tier 1 — Foreground** (<10s):
```bash
cargo check
```

**Tier 2 — Background with log file** (10s-5min):
```bash
mkdir -p .scratch/logs
(
  echo "[START] $(date '+%Y-%m-%d %H:%M:%S') — cargo test --all"
  cargo test --all
  EXIT_CODE=$?
  echo "[END] $(date '+%Y-%m-%d %H:%M:%S') — exit_code=$EXIT_CODE"
  exit $EXIT_CODE
) > .scratch/logs/test.log 2>&1 &
```

**Tier 3 — Tmux + Monitor** (>5min, auto-continuation):
```bash
tmux new-session -d -s "doit-build"
tmux send-keys -t "doit-build" '(
  echo "[START] $(date "+%Y-%m-%d %H:%M:%S") — cargo build --release"
  cargo build --release
  EXIT_CODE=$?
  echo "[END] $(date "+%Y-%m-%d %H:%M:%S") — exit_code=$EXIT_CODE"
  exit $EXIT_CODE
) > .scratch/logs/build.log 2>&1' Enter

Monitor "Watch build completion" \
  "grep -q '\[END\]' .scratch/logs/build.log" \
  --interval 30
```

When the monitor fires, Claude Code reads the log, checks the exit code, and **automatically continues to the next phase** without human intervention.

**No Monitor available?** Use `ScheduleWakeup` to poll periodically:
```
ScheduleWakeup delaySeconds=120 reason="polling build completion" prompt="check .scratch/logs/build.log for [END] marker"
```

See [background-process.md](background-process.md) for full patterns including multi-phase pipelines.

### Subagent Parallel TDD (Optional, Independent REQs Only)

**When:** 2+ REQs have no code dependencies (verified via tokensave code graph). Parallel execution can save 50-70% time.

**Before launching parallel agents:**
1. `tokensave_context(task="<REQ description>")` — verify no code dependencies between REQs
2. `tokensave_impact(node_id="<symbol>")` — check blast radius doesn't overlap

**Launch independent REQs as parallel agents:**
```
// REQ-001 and REQ-002 have no dependencies -> parallel
Agent({
  description: "Implement REQ-001",
  prompt: "Execute TDD for REQ-001: <full REQ description>. Use tokensave_str_replace for edits. Commit after RED->GREEN->REFACTOR.",
  subagent_type: "claude",
  isolation: "worktree",  // Independent git branch
  run_in_background: true
})

Agent({
  description: "Implement REQ-002",
  prompt: "Execute TDD for REQ-002: <full REQ description>. Use tokensave_str_replace for edits. Commit after RED->GREEN->REFACTOR.",
  subagent_type: "claude",
  isolation: "worktree",
  run_in_background: true
})

// 主流程继续：准备 Phase 4 E2E 测试计划
// 当后台 agent 完成后，合并 worktree 分支到主分支
```

**Merge worktree results:**
```bash
# After agents complete, merge their worktrees
git merge feat/req-001-branch --no-edit || { echo "merge conflict"; exit 1; }
git merge feat/req-002-branch --no-edit || { echo "merge conflict"; exit 1; }
```

**When NOT to parallelize:**
- REQs modify the same files → merge conflicts
- REQs have dependency relationships → sequential
- Single complex REQ → main flow handles it better

**Cost:** Each agent = separate API call. 2 parallel agents = 2x concurrent tokens, but ~50% faster total time.

## Phase 3 End

**When ALL REQs are done: proceed to Phase 4 (E2E). Code changes are NOT the end of the session.**

Full phase flow: Phase 4 → Phase 5 → Phase 6 → Phase 7 → Phase 8 (commit + push). Every phase runs. See SKILL.md Phase Gate Checklist.
