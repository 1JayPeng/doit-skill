# Review + Simplify

**MANDATORY.** Do not skip. Do not proceed until Review + Simplify pass.

**Principles applied here:**
- **Brevity First** — remove dead code, flatten abstractions, reduce line count
- **Surgical Edits** — only simplify what you wrote, don't refactor unrelated code
- **Goal-Driven Execution** — verify tests still pass; compare output against spec REQs

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
- `tokensave_similar(symbol="<new_function_name>")` — find similarly named symbols (naming inconsistency)
- `tokensave_signature_search(params="&mut self", returns="Result")` — find functions with matching signatures (potential duplicates)
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

### 1b. LSP Diagnostic Check (MANDATORY GATE)

Before any simplification, run the type-checker. No skip. No rationalize.

```
tokensave_diagnostics(scope="workspace")
```

Fallback: `cargo check`, `tsc --noEmit`, `pyright` — whatever matches the project.

**Gate:** If errors found -> fix them -> re-run until clean -> then proceed to Simplify.
**Why:** Simplify rewrites code. Starting simplify on a tree with type errors makes the changes harder to reason about. Fix first, simplify second.

### 2. Simplify — Cut the Fat

Apply these simplifications **without changing behavior**:

1. **Merge redundant code** — if two functions do similar things, is one enough?
2. **Remove dead imports/variables** — unused = gone
3. **Flatten unnecessary abstractions** — three identical lines > a 10-line helper
4. **Combine related operations** — two sequential loops over same data = one loop
5. **Shorten variable names** — `configuration` → `config`, `tempResult` → `result`

**tokensave tools for structural refactoring:**
- `tokensave_constructors(struct="<name>")` — find all struct literal sites (when adding/removing fields, update all construction sites)
- `tokensave_field_sites(field="<name>")` — find all read/write sites of a field (when renaming/removing fields)
- `tokensave_ast_grep_rewrite` — structural code rewrite via ast-grep CLI (batch renaming, pattern replacement)

**Simplify boundary**: stop when you're just renaming for the sake of it. "Does this reduce code I have to read?" is the test.

**⚠️ 批量编辑铁律 — 防止重复清理循环：**
- **先搜全量，再一次性编辑。** 任何清理操作（删变量、改引用、去 import、改排除列表），先用 `tokensave_field_sites` 或 `ctx_search` 找出文件中**所有**位置，然后用 `tokensave_multi_str_replace` 或单次 Edit 的 `replace_all` 一次性改完。
- **禁止分次清理同一类事物。** 不要"清理一处 → 检查 → 再清理一处"。一次找全 → 一次改完 → 验证完毕。
- **连续 2 次同类编辑 = 停止。** 如果刚对同一文件做了同类编辑（如两次都删 `context_cols`），说明第一次没搜全。改用 `tokensave_field_sites` 找全，然后批量处理。
- **验证替代重复。** 编辑完成后用 `ctx_search` 确认无残留，直接下一步。不要反复"检查剩余引用"而不做实际变更。

### 3. MemPalace Decision Check

**[MP-READ] If simplification contradicts a prior decision, find and update it:**
```
mempalace_search query="<simplification keywords>" wing="<project>" room="decisions" limit=3
```
If a stored decision is contradicted by the simplification:
```
mempalace_get_drawer drawer_id="<id from search>"
[MP-WRITE] mempalace_update_drawer drawer_id="<id>" content="<updated decision with rationale>"
```

### 4. Documentation Check

After writing code, check what documentation needs updating:

- [ ] README — if the feature changes how users interact with the project
- [ ] CLAUDE.md — if it changes how AI agents should work with the project
- [ ] AGENTS.md — if it's a skill or agent workflow change
- [ ] Module docstrings — if the new code is a public API

**Only update documentation that actually needs updating.** Don't create documentation for documentation's sake.

### 4. Final Verification

After simplifying, run:
1. **Tests still pass** — `ctx_execute` (auto-indexes output) or Bash fallback
1b. **`tokensave_diagnostics(scope="workspace")` — clean again after simplify (MANDATORY)**
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
