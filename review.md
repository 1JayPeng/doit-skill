# Phase 5: Review

## When

Trigger after all REQs DONE + Phase 4 initial e2e tests pass.

## Steps

### 1. Code Review

Run `code-review` skill. Focus:
- Duplicate logic -> extract shared function
- Dead code -> remove
- Over-abstraction -> flatten

**tokensave tools to prepare review context:**
1. `tokensave_diff_context(files=[<changed_files>])` — semantic diff of changed symbols
2. `tokensave_simplify_scan(files=[<changed_files>])` — duplications, dead code, coupling, complexity
3. `tokensave_dead_code()` — find symbols with no incoming edges
4. `tokensave_unused_imports()` — find unreferenced imports
- **Fallback:** If TokenSave unavailable -> `git diff` + `git diff --stat` manually review.

### 2. Architecture Check

Run `improve-codebase-architecture` skill for insight only. **Do not execute architectural refactors.** Suggest, don't break.

**tokensave tools for architecture analysis:**
1. `tokensave_dsm(path="<src_dir>", format="clusters")` — design structure matrix, reveals clusters and layering violations
2. `tokensave_coupling(direction="fan_in")` — which files are depended on most
3. `tokensave_coupling(direction="fan_out")` — which files depend on most others
4. `tokensave_hotspots()` — highest connectivity symbols (change blast radius)
5. `tokensave_dependency_depth()` — longest dependency chains, fragile files
6. `tokensave_health(details=true)` — composite quality signal with breakdown
- **Fallback:** If TokenSave unavailable -> `Agent Explore` for architectural overview.

### 3. Security Review

Run `security-review` skill. Check OWASP top 10.

**tokensave tools for security scanning:**
1. `tokensave_unsafe_patterns(kinds=["unwrap", "expect", "panic", "todo", "unimplemented", "unsafe_block"])` — surface panic/unsafe sites
2. `tokensave_todos(kinds=["HACK", "TODO"])` — find security-related TODOs
- **Fallback:** If TokenSave unavailable -> `grep -rn "TODO\|FIXME\|HACK\|unsafe" src/`.

### 4. Spec Final Check

Re-read `.spec/current.md`. Every REQ must be DONE. Gaps -> flag, don't auto-fix.

**tools for cross-referencing spec vs implementation:**
1. `tokensave_search(query="<REQ keyword>")` — verify the REQ functionality exists in code
2. `ctx_search(queries=[<REQ descriptions>])` — look up previously indexed spec content
- **Fallback:** Read `.spec/current.md` directly + `grep -rn` for keywords.

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
