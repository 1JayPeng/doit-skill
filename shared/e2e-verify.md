# E2E Verification Loop

**Runs after Review + Simplify.** Gate between simplify and commit. Used by both feature flow (Phase 7) and debug flow (D5).

Review + Simplify rewrites code. Rewritten code must be verified through the user-facing entry points — exactly what E2E tests check. **But passing tests is not enough — the output must match what the spec says.**

## The Problem

Simplify changes code. When E2E fails, the AI has an incentive to fix the test assertion to match the new (wrong) output rather than fix the code to match the original (correct) spec. **Spec alignment check prevents this.**

## Flow

```
Review+Simplify done
       ↓
  ┌─── Run all E2E tests ───────────────────┐
  │                                         │
  │  All tests pass? ── No ──→ Spec check:  │
  │  │                                      │
  │  │  Was assertion changed to match       │
  │  │  wrong output? → revert assertion    │
  │  │  Fix code to match spec, re-run ──┐  │
  │  │                                   │  │
  │  │                                   ↓  │
  │  Yes                                  │  │
  │  │                              (loop) │  │
  │  ↓                                     │  │
  │  Spec alignment check ←────────────────┘  │
  │  (compare actual output vs spec REQs)    │
  │  ↓                                        │
  │  Match? ── No ──→ Fix output to match    │
  │  │          spec, re-run                 │
  │  Yes                                      │
  │  ↓                                        │
  │  Commit                                    │
  └──────────────────────────────────────────┘
```

## Spec Alignment Step (each loop iteration)

After e2e tests pass, **before proceeding to commit**:

1. **Read `.spec/current.md`** (or bug report) — every REQ's expected behavior
2. **Re-run each e2e test, capture actual output** — don't trust the test pass/fail status
3. **Compare actual output against spec REQ, not against test assertion**
4. **Mismatch → fix the code output, not the test assertion**

## Tool Calling

### Run E2E Tests (each loop iteration)

**Primary (fast path — only affected tests):**
```
tokensave_affected_tests(files=[<files changed by simplify>])
tokensave_run_affected_tests(changed_paths=[<files changed by simplify>])
```
If `affected_tests` returns all tests (no narrowing), fall back to full suite.

**Fallback (full suite):**
```
ctx_execute(language="shell", code="uv run pytest tests/e2e/ -v --tb=short")
```
- **Context-Mode unavailable:** native Bash tool.

### Spec Alignment Tools

Compare actual output against spec:
1. `ctx_search(queries=[<REQ descriptions from spec>])` — look up REQ expectations from indexed content
   - **Fallback:** Read `.spec/current.md` directly.
2. `tokensave_diff_context(files=[<files changed by simplify>])` — which symbols simplify actually changed
   - **Fallback:** `git diff --name-only` + `git diff <file>`.
3. `tokensave_changelog(from_ref="<base_branch>", to_ref="HEAD")` — structured diff of all changes on branch
   - **Fallback:** `git diff <base>...HEAD`.

## Rules

- **Run all E2E tests again** — L0 + L1 + L2 + L3
- **Don't skip** — simplify touched code. Verify the touch didn't break user-facing behavior.
- **Spec is ground truth** — when test output differs from spec, fix the code. Never change the spec to match a broken output.
- **Don't change test assertions** — if a test fails because simplify broke behavior, the test is correct and the code is wrong.
- **Debug narrowly** — the regression is a specific simplify change. Find it, fix it or revert it.
- **Loop limit** — if e2e fails more than 3 times, escalate to user: "simplify broke more than it helped. Roll back Review+Simplify and proceed with original code."
- **Each loop iteration logs** what broke, what the spec says, and what fix was applied.
