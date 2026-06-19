# Phase 5: Review

## When

Trigger after all REQs DONE + Phase 4 initial e2e tests pass.

## Steps

### 1. MemPalace Context

**[MP-READ] Search for prior review findings (before starting review):**
```
mempalace_search query="<feature> review" wing="<project>" room="reviews" limit=3
```
Use findings to avoid repeating already-identified issues.

### 2. Code Review

**Caveman review (optional, recommended):** If caveman skill available, run `/caveman-review` for caveman-style code review. This provides terse, direct feedback on code quality.

Run `code-review` skill. Focus:
- Duplicate logic -> extract shared function
- Dead code -> remove
- Over-abstraction -> flatten

**codegraph tools for code review (use flexibly, pick what fits):**
- `codegraph_context(task="<feature>")` — understand the changes in context
- `codegraph_search("symbolName")` — find specific symbols
- `codegraph_callers(symbol)` / `codegraph_callees(symbol)` — call chains
- `codegraph_impact(symbol)` — blast radius of changes
- `codegraph_explore(query)` — inspect multiple related symbols
- **Fallback:** `git diff` + `git diff --stat` + manual review.

#### Subagent Parallel Review (Optional, when multiple review dimensions)

Security, Architecture, and Complexity reviews are independent → run concurrently. See [subagent.md](subagent.md) for full patterns.

```
// Parallel review agents
Agent({
  description: "Security review",
  prompt: "Run security review: grep for unsafe patterns, TODO/FIXME markers, check public API surface. Report all security vulnerabilities.",
  subagent_type: "general-purpose",
  run_in_background: true
})

Agent({
  description: "Architecture review",
  prompt: "Run architecture review: check coupling, hotspots, dependency depth using codegraph. Report structural issues.",
  subagent_type: "Plan",
  run_in_background: true
})

// 主流程继续：准备 Spec Final Check
// 当后台 agent 完成后，汇总 2 个审查报告
```

**Merge results:** Combine findings into a single review report. Prioritize: Security > Architecture.

### 2. Architecture Check

Run `improve-codebase-architecture` skill for insight only. **Do not execute architectural refactors.** Suggest, don't break.

**codegraph tools for architecture analysis:**
- `codegraph_context(task="<architecture concern>")` — understand architectural patterns
- `codegraph_files` — project file structure
- **Fallback:** `grep -rn` + `find` for architectural overview.

### 3. Security Review

**Fallback:** `grep -rn "TODO\|FIXME\|HACK\|unsafe" src/`.

### 4. Spec Final Check

Re-read `.spec/current.md`. Every REQ must be DONE. Gaps -> flag, don't auto-fix.

**codegraph tools for cross-referencing spec vs implementation:**
- `codegraph_search(query="<REQ keyword>")` — verify the REQ functionality exists in code
- `codegraph_context(task="<REQ description>")` — get relevant code context for the REQ
- `ctx_search(queries=[<REQ descriptions>])` — look up previously indexed spec content
- **Fallback:** Read `.spec/current.md` directly + `grep -rn` for keywords.

**[MP-WRITE] File review findings for cross-session reference:**
```
mempalace_add_drawer wing="<project>" room="reviews" content="Review: <summary>, issues: <X>, patterns: <Y>"
mempalace_kg_add subject="<project>" predicate="passed_review" object="<feature name>" valid_from="<today>"
```

### 5. RTK Token Report

Run `rtk discover` to scan this session's commands for missed optimization opportunities.
Run `rtk gain --history` to show per-command token savings history.

### 6. Phase 6 Next (MANDATORY)

**After Phase 5 completes, you MUST run Phase 6 Review+Simplify.** See [shared/review-simplify.md](shared/review-simplify.md).
This is where you check your own work for:
- Code that works but is over-engineered
- Missed README/CLAUDE.md updates
- Documentation that doesn't match new behavior

**Do not proceed to Archive without Phase 6.**

### 7. Archive

All REQs DONE + Phase 6 passes + user confirms:
```bash
mv .spec/current.md .spec/archive/feature-name-$(date +%Y%m%d).md
git add .spec/
git commit -m "archive spec: feature-name"
```
