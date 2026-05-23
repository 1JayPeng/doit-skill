# Phase 6: Review + Simplify

**MANDATORY.** Do not skip. Do not proceed until Review + Simplify pass.

## When to Run

- **Per-REQ Review**: After each REQ completes in Phase 3 Execute
- **Final Review**: After all REQs complete and Phase 5 passes

## Steps

### 1. Review — Read What You Wrote

Read every file you modified. Not just the diff — read the full context around changes.

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
1. Tests still pass
2. `codegraph_context` — verify the changes integrate cleanly with the codebase
3. `ctx_search` — verify documentation matches new behavior (search for references to old functionality)
4. One final read of the modified files — do they still read correctly after simplifying?

## Gate

Review + Simplify is a **hard gate**. Code does not proceed to Phase 4 or merge until this passes.

If you catch yourself thinking "this looks fine, let me move on" — that's exactly when you skip review and leave junk in. Read what you wrote. Cut what's unnecessary.
