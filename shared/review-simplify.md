# Review + Simplify

**MANDATORY.** Do not skip. Do not proceed until Review + Simplify pass.

## When to Run

- **Per-REQ Review**: After each REQ completes in Phase 3 Execute
- **Final Review (Feature)**: After all REQs complete and Phase 5 passes
- **After Bug Fix**: After D2 Fix completes

## Steps

### 1. Review — Read What You Wrote

Read every file you modified. Not just the diff — read the full context around changes.

**tokensave tools for review (pick what fits, don't call all of them):**

Code health baseline:
- `tokensave_health(details=true)` — composite quality signal, structural risk before review

Semantic analysis of changes:
- `tokensave_diff_context(files=[<changed_files>])` — symbols modified, dependents, affected tests
- `tokensave_simplify_scan(files=[<changed_files>])` — duplications, dead code, coupling, complexity

Code quality scanning:
- `tokensave_dead_code()` — symbols with no incoming edges (potentially unreachable)
- `tokensave_unused_imports()` — unreferenced imports
- `tokensave_complexity(path="<changed_dir>", limit=5)` — highest complexity functions
- `tokensave_god_class(path="<changed_dir>", limit=5)` — classes with most members (too many responsibilities)
- `tokensave_coupling(direction="fan_in", path="<changed_dir>")` — files depended on most
- `tokensave_coupling(direction="fan_out", path="<changed_dir>")` — files with most dependencies
- `tokensave_dependency_depth(limit=5)` — longest file-level dependency chains (fragile to upstream changes)
- `tokensave_doc_coverage(path="<src_dir>")` — public symbols missing documentation
- `tokensave_circular()` — circular dependencies between files
- `tokensave_recursion(limit=5)` — recursive or mutually-recursive call cycles

Discovery (when you need to find specific code):
- `tokensave_search(query="<symbol name>")` — find specific symbols by name
- `tokensave_node(node_id="<id>")` — full details + source for a specific symbol
- `tokensave_callers(node_id="<id>")` — what calls this function
- `tokensave_callees(node_id="<id>")` — what does this function call
- `tokensave_impact(node_id="<id>")` — full blast radius of changing a symbol
- `tokensave_files(path="<dir>")` — list indexed project files

Type system (when reviewing interfaces, traits, classes):
- `tokensave_type_hierarchy(node_id="<id>")` — recursive type hierarchy tree
- `tokensave_rank(edge_kind="implements", direction="incoming")` — most implemented interface
- `tokensave_distribution(path="<dir>")` — node kind breakdown
- `tokensave_largest(node_kind="class", limit=5)` — largest classes

Git & Workflow (for commit preparation, PR descriptions):
- `tokensave_commit_context()` — semantic summary of uncommitted changes
- `tokensave_pr_context(head_ref="HEAD", base_ref="<base>")` — semantic diff for PR descriptions
- `tokensave_changelog(from_ref="<base>", to_ref="HEAD")` — semantic diff between refs
- `tokensave_test_map(node_id="<id>")` — source-to-test mapping, uncovered symbols

- **Fallback:** If TokenSave unavailable -> `git diff` + manual `Read` of changed files.

Check:
- [ ] Code does what the spec says (not what I thought it said)
- [ ] No commented-out code or debugging artifacts
- [ ] No TODO/FIXME placeholders (unless explicitly agreed with user)
- [ ] No duplicated logic that exists elsewhere in the codebase
- [ ] Error messages are meaningful (not generic "something went wrong")

### 2. Simplify — Cut the Fat

Apply these simplifications **without changing behavior**:

1. **Merge redundant code** — if two functions do similar things, is one enough?
2. **Remove dead imports/variables** — unused = gone
3. **Flatten unnecessary abstractions** — three identical lines > a 10-line helper
4. **Combine related operations** — two sequential loops over same data = one loop
5. **Shorten variable names** — `configuration` → `config`, `tempResult` → `result`

**Simplify boundary**: stop when you're just renaming for the sake of it. "Does this reduce code I have to read?" is the test.

### 3. Documentation Check

After writing code, check what documentation needs updating:

- [ ] README — if the feature changes how users interact with the project
- [ ] CLAUDE.md — if it changes how AI agents should work with the project
- [ ] AGENTS.md — if it's a skill or agent workflow change
- [ ] Module docstrings — if the new code is a public API

**Only update documentation that actually needs updating.** Don't create documentation for documentation's sake.

### 4. Final Verification

After simplifying, run:
1. **Tests still pass** — `ctx_execute` (auto-indexes output) or Bash fallback
2. `tokensave_health(path="<changed_dir>")` — verify quality signal didn't degrade
3. `tokensave_simplify_scan(files=[<changed_files>])` — verify no new duplications introduced
4. `tokensave_diff_context(files=[<changed_files>])` — verify changes integrate cleanly
5. `ctx_search(queries=[<old_functionality_keywords>])` — verify documentation matches new behavior
6. One final read of the modified files — do they still read correctly after simplifying?

**Fallback for all TokenSave tools:** `git diff <files>` + manual `Read`.
**Fallback for ctx_search:** `grep -rn "<keyword>" .` — search docs manually.

## Gate

Review + Simplify is a **hard gate**. Code does not proceed until this passes, then enters E2E Verification Loop.

If you catch yourself thinking "this looks fine, let me move on" — that's exactly when you skip review and leave junk in. Read what you wrote. Cut what's unnecessary.

## Next Step

E2E Verification Loop — [e2e.md](../e2e.md) § E2E Verification Loop
