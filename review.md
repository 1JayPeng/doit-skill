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
- `codegraph_callers(symbol)` — see what calls a changed symbol (blast radius)
- `codegraph_impact(symbol)` — assess edit blast radius
- `codegraph_node(symbol)` — inspect full symbol source

**Fallback (requires tokensave) — advanced analysis tools:**
- `tokensave_health(details=true)` — baseline quality signal before review
- `tokensave_diff_context(files=[<changed_files>])` — semantic diff of changed symbols, dependents, affected tests
- `tokensave_simplify_scan(files=[<changed_files>])` — auto-detect duplications, dead code, coupling, complexity
- `tokensave_dead_code()` — find symbols with no incoming edges (potentially unreachable)
- `tokensave_unused_imports()` — find unreferenced import/use nodes
- `tokensave_complexity(path="<changed_dir>", limit=5)` — rank functions by complexity, find hotspots
- `tokensave_circular()` — detect circular file dependencies
- `tokensave_recursion()` — detect recursive/mutually-recursive call cycles
- `tokensave_similar(symbol="<new_function_name>")` — find similarly named symbols
- `tokensave_signature_search(params="&mut self", returns="Result")` — find functions with matching signatures
- `tokensave_diagnostics(scope="workspace")` — run type-checker (cargo check / tsc / pyright) before committing
- **Fallback:** If tokensave unavailable -> `git diff` + `git diff --stat` manually review.

#### Subagent Parallel Review (Optional, when multiple review dimensions)

Security, Architecture, and Complexity reviews are independent → run concurrently. See [subagent.md](subagent.md) for full patterns.

```
// Parallel review agents
Agent({
  description: "Security review",
  prompt: "Run security review: codegraph_context for '<feature>' security analysis. If tokensave installed, also run tokensave_unsafe_patterns, tokensave_todos, tokensave_module_api. Report all security vulnerabilities.",
  subagent_type: "general-purpose",
  run_in_background: true
})

Agent({
  description: "Architecture review",
  prompt: "Run architecture review: codegraph_context for '<feature>' structural analysis. If tokensave installed, also run tokensave_dsm, tokensave_coupling, tokensave_hotspots. Report structural issues.",
  subagent_type: "Plan",
  run_in_background: true
})

Agent({
  description: "Complexity review",
  prompt: "Run complexity review: codegraph_context for '<feature>' complexity analysis. If tokensave installed, also run tokensave_complexity, tokensave_god_class, tokensave_gini. Report complexity hotspots.",
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

**Fallback (requires tokensave) — advanced architecture analysis:**
- `tokensave_dsm(path="<src_dir>", format="clusters")` — design structure matrix, reveals clusters and layering violations
- `tokensave_coupling(direction="fan_in")` — which files are depended on most (high coupling risk)
- `tokensave_coupling(direction="fan_out")` — which files depend on most others (fragile modules)
- `tokensave_hotspots()` — highest connectivity symbols (change blast radius)
- `tokensave_dependency_depth()` — longest dependency chains, fragile files
- `tokensave_gini(metric="complexity")` — find god files with uneven complexity distribution
- **Fallback:** If tokensave unavailable -> `grep -rn` + `find` for architectural overview.

### 3. Security Review

**codegraph tools for security scanning:**
- `codegraph_search("unsafe")` — find unsafe code patterns
- `codegraph_search("TODO")` — find TODO/FIXME/HACK markers

**Fallback (requires tokensave) — advanced security scanning:**
- `tokensave_unsafe_patterns(kinds=["unwrap", "expect", "panic", "todo", "unimplemented", "unsafe_block"])` — surface panic/unsafe sites
- `tokensave_todos(kinds=["HACK", "TODO"])` — find security-related TODOs
- `tokensave_doc_coverage(path="<src_dir>")` — public symbols missing documentation (API surface gaps)
- `tokensave_test_risk(path="<src_dir>")` — risk-weighted test-gap analysis (high risk = high fan-in + low coverage)
- `tokensave_module_api(path="<src_dir>")` — public API surface (attack surface inventory)
- **Fallback:** If TokenSave unavailable -> `grep -rn "TODO\|FIXME\|HACK\|unsafe" src/`.

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
