# Phase 3: Execute (Tool-Agnostic)

**[LOAD:phase-3] tdd** → `[[SKILL:route target="tdd"]]`

## Rules

- Per-REQ TDD loop: CONTEXT → IMPLEMENT → RED → GREEN → TEST GATE → REFACTOR → REVIEW+SIMPLIFY
- Use native edit primitives for file changes (Edit, StrReplace, Write)
- MCP tools (codegraph, context-mode, mempalace) remain unchanged — they are tool-agnostic
- Fallback: If codegraph unavailable → `grep` + `find` + `[[FILE:read]]`

**LSP-powered refactoring (lean-ctx):**
- `ctx_refactor(action="rename", path="<file>", line=<N>, new_name="<name>")` — rename symbol
- `ctx_refactor(action="references", path="<file>", line=<N>)` — find references
- `ctx_refactor(action="definition", path="<file>", line=<N>)` — go to definition

## TDD Loop per REQ

### CONTEXT (before RED)

**[CALL]** Before writing any code:
```
[CALL] codegraph_context(task="<REQ description>") — understand feature flow, get relevant symbols + relationships
[CALL] codegraph_impact(symbol="<symbol>") — blast radius check
```

If codegraph unavailable → `grep` + `find` + `[[FILE:read]]` fallback.

### IMPLEMENT — Reuse Gate (MANDATORY before writing any code)

Before writing code, check:
1. Is there existing code that does this? → `codegraph_search`
2. Can I reuse it? → Read existing code via `codegraph_node` / `[[FILE:read]]`
3. Only write new code if reuse is not possible.

### IMPLEMENT (edit primitives for code changes)

**Edit chain:**
```
1. [[FILE:edit]] (native search-and-replace, preferred)
2. [[FILE:write]] (complete file rewrite, last resort)
```

### RED

Write test that fails. Use `[[SHELL:run]]` to run tests.
```
[[SHELL:run command="cargo test test_name 2>&1 | tail -20"]]
# or
[[SHELL:run command="pytest -xvs tests/test_file.py::test_name"]]
```

**RED 验证：测试必须失败。** 如果测试写了就跑过，说明测试没验证任何东西。重写测试。

### GREEN

Write minimal implementation. Run tests again — must pass.

### TEST QUALITY GATE (MANDATORY after GREEN)

Before moving to REFACTOR, verify the test actually tests the right thing. Run through each check — do NOT ask user:

1. **Always-pass check**: Comment out the implementation. Does the test FAIL?
   - NO → test is useless, rewrite it
   - YES → proceed

2. **Mock audit**: Does the test mock any internal collaborator?
   - YES → is it a system boundary? If NO, replace mock with real instance
   - Document each mock: why system boundary, what would happen without it

3. **Impl-coupling check**: Would renaming an internal function break this test?
   - YES → test is coupled to impl, rewrite through public interface
   - NO → proceed

4. **Assertion check**: Does the test assert OUTPUT or CALLS?
   - Asserts calls (e.g., `toHaveBeenCalledWith`) → rewrite to assert output/behavior
   - Asserts output → proceed

5. **Coverage check**: Does the test cover at least happy path + one negative case?
   - Missing negative case → add one (invalid input, missing field, wrong permission)
   - Both present → proceed

6. **Real-path check**: Does the test exercise the same code path that production would use?
   - Test uses a mock where prod uses a real service (not a system boundary) → replace with real path
   - Same path → proceed

**Only proceed to REFACTOR after all gates pass.**

### REFACTOR

Refactor while keeping tests green.

### REVIEW + SIMPLIFY (MANDATORY after each REQ)

After each REQ implementation:
```
[[SHELL:run command="git diff --stat"]]
```
Remove dead code, flatten abstractions, eliminate duplicates. Use `git diff` + manual review.

### Worklog Write (MANDATORY after each REQ)

Write worklog entry to `.doit/worklog.json`.

### Test Execution

```
[[SHELL:run command="cargo test --lib 2>&1 | tail -30"]]
```
Tests must pass before proceeding to next REQ.

### Spec Alignment Check (Non-Interruptive)

After REQ complete, verify against spec REQ criteria.

### Background Process Management (铁律)

- **<10s** → `[[SHELL:run command="..."]]` (foreground)
- **>=10s** → `[[SHELL:run command="..." background=true]]`
- **>=5min** → tmux + Monitor or `[[SCHEDULE:wakeup]]`

### Subagent Decision Gate (MANDATORY — Execute Before First REQ)

Read `.doit/config.yaml` `subagent.enabled`. If `true` and 2+ REQs with no code dependencies → parallel execution. See [subagent.md](subagent.md).

### State Tracking

Track REQ status in `.doit/state.json`:
```json
{
  "REQ-001": { "status": "completed", "tests": "PASS", "files": ["..."] },
  "REQ-002": { "status": "in_progress", "tests": null, "files": null }
}
```

## Phase 3 End

All REQs completed → Phase 3 done. Verify all REQs pass tests.
