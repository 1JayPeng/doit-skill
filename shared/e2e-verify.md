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

## Rules

- **Run all E2E tests again** — L0 + L1 + L2 + L3
- **Don't skip** — simplify touched code. Verify the touch didn't break user-facing behavior.
- **Spec is ground truth** — when test output differs from spec, fix the code. Never change the spec to match a broken output.
- **Don't change test assertions** — if a test fails because simplify broke behavior, the test is correct and the code is wrong.
- **Debug narrowly** — the regression is a specific simplify change. Find it, fix it or revert it.
- **Loop limit** — if e2e fails more than 3 times, escalate to user: "simplify broke more than it helped. Roll back Review+Simplify and proceed with original code."
- **Each loop iteration logs** what broke, what the spec says, and what fix was applied.

## State Persistence

When e2e verification loop passes:
```json
{
  "phase": "e2e-verify",
  "e2e_verify": "passed",
  "spec_alignment": "passed",
  "loop_iterations": N
}
```
