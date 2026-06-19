# Phase 3: Execute (Tool-Agnostic)

**[LOAD:phase-3] tdd** → `[[SKILL:route target="tdd"]]`

## Rules

- Per-REQ TDD loop: CONTEXT → IMPLEMENT → RED → GREEN → REFACTOR → REVIEW+SIMPLIFY
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
[CALL] codegraph_context(task="<REQ description>")
[CALL] codegraph_impact(symbol="...") — blast radius check
```

If codegraph unavailable → `grep` + `find` + `[[FILE:read]]` fallback.

### IMPLEMENT — Reuse Gate (MANDATORY before writing any code)

Before writing code, check:
1. Is there existing code that does this? → `codegraph_search`
2. Can I reuse it? → Read existing code via `codegraph_node` / `[[FILE:read]]`
3. Only write new code if reuse is not possible.

### IMPLEMENT (edit primitives for code changes)

Use `[[FILE:edit]]` for file changes:
- `[[FILE:edit]]` — search-and-replace (native tool, safe single-edit)

**Fallback chain:**
```
1. [[FILE:edit]] (native search-and-replace)
2. [[FILE:write]] (complete file rewrite, last resort)
```

### RED

Write test that fails. Use `[[SHELL:run]]` to run tests.
```
[[SHELL:run command="cargo test test_name 2>&1 | tail -20"]]
# or
[[SHELL:run command="pytest -xvs tests/test_file.py::test_name"]]
```

### GREEN

Write minimal implementation. Run tests again — must pass.

### REFACTOR

Refactor while keeping tests green.

### REVIEW + SIMPLIFY (MANDATORY after each REQ)

After each REQ implementation:
```
[[SHELL:run command="git diff --stat"]]
```
Remove dead code, flatten abstractions, eliminate duplicates. Manual review via `[[SHELL:run]]` git diff + `[[FILE:read]]`.

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
