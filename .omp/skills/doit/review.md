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

**Ponytail reuse check (mandatory first):** Run `/ponytail` before review decisions. Check in order: existing codebase reuse → standard library/标准库 → native platform → installed dependency → GitHub/reference implementation. If GitHub code can be borrowed/copied, prefer the smallest license-compatible copy or direct reuse, cite the source, and avoid new custom code. Run `/ponytail-review` if available as the final complexity pass.

**Caveman review (optional, recommended):** If caveman skill available, run `/caveman-review` for caveman-style code review. This provides terse, direct feedback on code quality.

Run `code-review` skill. Focus:
- Duplicate logic -> extract shared function
- Dead code -> remove
- Over-abstraction -> flatten

**codegraph tools for code review (use flexibly, pick what fits):**
- `codegraph_callers(symbol)` — see what calls a changed symbol (blast radius)
- `codegraph_impact(symbol)` — assess edit blast radius
- `codegraph_node(symbol)` — inspect full symbol source

**Fallback:** `codegraph_context` + `codegraph_search` for structural analysis.
- **Fallback:** `git diff` + `git diff --stat` for manual review.

#### Subagent Parallel Review (Optional, when multiple review dimensions)

Security, Architecture, and Complexity reviews are independent → run concurrently. See [subagent.md](subagent.md) for full patterns.

```
// Parallel review agents
Agent({
  description: "Security review",
  prompt: "Run security review: codegraph_context for '<feature>' security analysis.  Report all security vulnerabilities.",
  subagent_type: "general-purpose",
  run_in_background: true
})

Agent({
  description: "Architecture review",
  prompt: "Run architecture review: codegraph_context for '<feature>' structural analysis.  Report structural issues.",
  subagent_type: "Plan",
  run_in_background: true
})

Agent({
  description: "Complexity review",
  prompt: "Run complexity review: codegraph_context for '<feature>' complexity analysis.  Report complexity hotspots.",
  subagent_type: "general-purpose",
  run_in_background: true
})

// 主流程继续：准备 Spec Final Check
// 当后台 agent 完成后，汇总 3 个审查报告
```

**Merge results:** Combine findings into a single review report. Prioritize: Security > Architecture > Complexity.

### 2. Architecture Check

Run `improve-codebase-architecture` skill for insight only. **Do not execute architectural refactors.** Suggest, don't break.

**Manual trigger:** At any time, run `/improve-codebase-architecture` to get a deep architectural analysis. No automatic trigger exists — this is an on-demand skill.

**Fallback:** `codegraph_impact` + `codegraph_search` for architectural overview.

### 3. Security Review

**codegraph tools for security scanning:**
- `codegraph_search("unsafe")` — find unsafe code patterns
- `codegraph_search("TODO")` — find TODO/FIXME/HACK markers

**Fallback:** `codegraph_search` + `grep -rn` for security scanning.
- **Fallback:** If TokenSave unavailable -> `grep -rn "TODO\|FIXME\|HACK\|unsafe" src/`.

### 4. Spec Final Check + 偏离检查

Re-read `.spec/current.md`. Every REQ must be DONE. Gaps -> flag, don't auto-fix.

For each REQ, classify implementation/spec mismatch:
- **左偏离 (encouraged):** implementation fully satisfies the REQ, improves on the spec, is integrated into the main system, and is callable from the normal path → update `.spec/current.md` to match reality.
- **右偏离 (fix):** implementation is fake or isolated, matches only function/file names, or is unused by the normal path → loop back to Phase 3 and wire/fix it.
- **部分偏离 (fix):** only part of the REQ is implemented → loop back to Phase 3 for the missing behavior.
- **完全偏离/未实现 (fix):** implementation does not address the REQ, or no implementation exists → loop back to Phase 3 for that REQ.

**偏离检查 gate:** Only 左偏离 may pass Phase 5, and it must update the spec before continuing.

**codegraph tools for cross-referencing spec vs implementation:**

**[MP-WRITE] File review findings for cross-session reference:**
```
mempalace_add_drawer wing="<project>" room="reviews" content="Review: <summary>, issues: <X>, patterns: <Y>"
mempalace_kg_add subject="<project>" predicate="passed_review" object="<feature name>" valid_from="<today>"
```

### 5. RTK Token Report

Run `rtk discover` to scan this session's commands for missed optimization opportunities.
Run `rtk gain --history` to show per-command token savings history.

### 6. Phase 6 Next (MANDATORY)

**After Phase 5 completes, you MUST run Phase 6 Review+Simplify.** See [core/shared/review-simplify.md](core/shared/review-simplify.md).
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
