# Phase 5: Review

## When

Trigger after all REQs DONE + Phase 4 initial e2e tests pass.

## Steps

### 1. Code Review

Run `code-review` skill. Focus:
- Duplicate logic -> extract shared function
- Dead code -> remove
- Over-abstraction -> flatten

**tokensave tools for code review (use flexibly, pick what fits):**
- `tokensave_health(details=true)` — baseline quality signal before review
- `tokensave_diff_context(files=[<changed_files>])` — semantic diff of changed symbols, dependents, affected tests
- `tokensave_simplify_scan(files=[<changed_files>])` — auto-detect duplications, dead code, coupling, complexity
- `tokensave_dead_code()` — find symbols with no incoming edges (potentially unreachable)
- `tokensave_unused_imports()` — find unreferenced import/use nodes
- `tokensave_complexity(path="<changed_dir>", limit=5)` — rank functions by complexity, find hotspots
- `tokensave_circular()` — detect circular file dependencies
- `tokensave_recursion()` — detect recursive/mutually-recursive call cycles
- `tokensave_similar(symbol="<new_function_name>")` — find similarly named symbols (naming inconsistency = potential confusion)
- `tokensave_signature_search(params="&mut self", returns="Result")` — find functions with matching signatures (potential duplicates)
- `tokensave_diagnostics(scope="workspace")` — run type-checker (cargo check / tsc / pyright) before committing
- **Fallback:** If TokenSave unavailable -> `git diff` + `git diff --stat` manually review.

### 2. Architecture Check

Run `improve-codebase-architecture` skill for insight only. **Do not execute architectural refactors.** Suggest, don't break.

**tokensave tools for architecture analysis (use flexibly, pick what fits):**
- `tokensave_dsm(path="<src_dir>", format="clusters")` — design structure matrix, reveals clusters and layering violations
- `tokensave_coupling(direction="fan_in")` — which files are depended on most (high coupling risk)
- `tokensave_coupling(direction="fan_out")` — which files depend on most others (fragile modules)
- `tokensave_hotspots()` — highest connectivity symbols (change blast radius)
- `tokensave_dependency_depth()` — longest dependency chains, fragile files
- `tokensave_gini(metric="complexity")` — find god files with uneven complexity distribution
- `tokensave_inheritance_depth()` — deepest class/interface hierarchies
- `tokensave_type_hierarchy(node_id="<id>")` — full type hierarchy tree for traits/interfaces/classes
- `tokensave_rank(edge_kind="implements", direction="incoming")` — most implemented interface (high coupling risk)
- `tokensave_distribution(path="<dir>")` — node kind breakdown per file/directory
- `tokensave_largest(node_kind="class", limit=5)` — largest classes (potential god classes)
- **Fallback:** If TokenSave unavailable -> `Agent Explore` for architectural overview.

### 3. Security Review (tokensave-based)

Use tokensave tools for security scanning instead of `security-review` skill:

**tokensave tools for security scanning:**
- `tokensave_unsafe_patterns(kinds=["unwrap", "expect", "panic", "todo", "unimplemented", "unsafe_block"])` — surface panic/unsafe sites
- `tokensave_todos(kinds=["HACK", "TODO"])` — find security-related TODOs
- `tokensave_doc_coverage(path="<src_dir>")` — public symbols missing documentation (API surface gaps)
- `tokensave_test_risk(path="<src_dir>")` — risk-weighted test-gap analysis (high risk = high fan-in + low coverage)
- `tokensave_module_api(path="<src_dir>")` — public API surface (attack surface inventory)
- **Fallback:** If TokenSave unavailable -> `grep -rn "TODO\|FIXME\|HACK\|unsafe" src/`.

### 4. Spec Final Check

Re-read `.spec/current.md`. Every REQ must be DONE. Gaps -> flag, don't auto-fix.

**tokensave tools for cross-referencing spec vs implementation:**
- `tokensave_search(query="<REQ keyword>")` — verify the REQ functionality exists in code
- `tokensave_context(task="<REQ description>")` — get relevant code context for the REQ
- `ctx_search(queries=[<REQ descriptions>])` — look up previously indexed spec content
- **Fallback:** Read `.spec/current.md` directly + `grep -rn` for keywords.

**MemPalace** (if available): file review findings for cross-session reference:
```
mempalace_add_drawer wing="<project>" room="reviews" content="Review: <summary>, issues: <X>, patterns: <Y>"
mempalace_kg_add subject="<project>" predicate="passed_review" object="<feature name>" valid_from="<today>"
```

### 5. RTK Token Report

Run `rtk discover` to scan this session's commands for missed optimization opportunities.
Run `rtk gain --history` to show per-command token savings history.

### 5. Phase 6 Next (MANDATORY)

**After Phase 5 completes, you MUST run Phase 6 Review+Simplify.** See [review-simplify.md](review-simplify.md).
This is where you check your own work for:
- Code that works but is over-engineered
- Missed README/CLAUDE.md updates
- Documentation that doesn't match new behavior

**Do not proceed to Archive without Phase 6.**

### 6. Archive

All REQs DONE + Phase 6 passes + user confirms:
```bash
mv .spec/current.md .spec/archive/feature-name-$(date +%Y%m%d).md
git add .spec/
git commit -m "archive spec: feature-name"
```
