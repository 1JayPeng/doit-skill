# Phase 4: End-to-End Testing

## Rules

- E2E tests run in real project environment (uv venv)
- Every entry point tested. Every entry parameter tested.
- If automation is hard -> HITL (hand it to user)

## What E2E is NOT

Phase 3 unit tests cover: internal functions, mocked dependencies, isolated paths.
Phase 4 E2E tests cover: real entry points, real I/O, integration of all layers.

**E2E ≠ "unit tests but with subprocess."** You're testing the user's full journey, not function signatures.

**Common anti-pattern:** Replacing `import main` with `subprocess.run` but still asserting internal state. Instead assert: exit code, stdout/stderr, file output, database state — things the user observes.

## Test Level Taxonomy

| Level | What | Auto? |
|-------|------|-------|
| L0 | Required params, happy path | Yes |
| L1 | Boundary values (empty, max, min, special chars) | Yes |
| L2 | Conflicting param combinations | HITL |
| L3 | Fuzzy/random input, stability | HITL |

## L0/L1 Auto-Generate

For each entry point (function, CLI command, API):

1. List all parameters from signature
2. Generate L0: one valid call per entry point
3. Generate L1: boundary for each param

```python
# Auto-generated e2e skeleton
import subprocess, sys

def run_entry(name, args):
    result = subprocess.run([sys.executable, "-m", "main"] + args, capture_output=True, text=True)
    return result

# L0: happy path
run_entry("login", ["--user", "test", "--pass", "abc123"])

# L1: boundary
run_entry("login", ["--user", "", "--pass", "abc123"])  # empty user
```

## L2/L3 HITL

Present untested combinations to user:
```
L2 HITL: These param combos need manual testing:
  1. --flag-a + --flag-b (conflict expected?)
  2. --mode=debug + --verbose (redundant?)

Run each, paste output. I'll generate assertion.
```

## E2E + Spec Cross-Check

Compare e2e coverage against spec acceptance criteria. Missing -> flag to user.

### Spec Alignment Check (per REQ)

**E2E tests are not just about code running — they verify output matches what the user asked for.**

For each REQ in `.spec/current.md`:

1. Read REQ description and expected behavior
2. Find the e2e test that covers this REQ
3. Run the test, capture actual output
4. **Compare actual output against spec expectation — not the test assertion**

```
REQ-001: "user can login and see dashboard"
  Expected: dashboard page with user greeting
  Actual:   "Welcome back, test" on /dashboard URL
  Match?    Yes

REQ-002: "unauthorized access returns 403"
  Expected: 403 error, no page content
  Actual:   401 error, login redirect
  Match?    No — wrong status code and behavior differs from spec
```

**Key: compare output against spec, not against test assertion.** The test assertion might have been changed to match wrong output (AI lying to itself). Always read the spec as the ground truth.

## State Persistence

After Phase 4 completes (all L0+L1 tests run):
Write to `.scratch/workflow-state.json`:
```json
{ "phase": "e2e", "e2e": "passed", "l0_entry_points": N, "l1_boundary_values": M }
```
If tests failed: `"e2e": "failed"`. This is what Phase 5 pre-flight gate checks.

## E2E Verification Loop (Phase 7)

**This runs after Phase 6 (Review + Simplify) completes.** It is the gate between simplify and commit.

Review + Simplify rewrites code. Rewritten code must be verified through the user-facing entry points — exactly what E2E tests check. **But passing tests is not enough — the output must match what the spec says.**

### The Problem

Simplify changes code. When E2E fails, the AI has an incentive to fix the test assertion to match the new (wrong) output rather than fix the code to match the original (correct) spec. **Spec alignment check prevents this.**

### Flow

```
Phase 6 Review+Simplify done
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
  │  Phase 8 Commit                           │
  └──────────────────────────────────────────┘
```

### Spec Alignment Step (each loop iteration)

After e2e tests pass, **before proceeding to commit**:

1. **Read `.spec/current.md`** — every REQ's expected behavior
2. **Re-run each e2e test, capture actual output** — don't trust the test pass/fail status
3. **Compare actual output against spec REQ, not against test assertion**
4. **Mismatch → fix the code output, not the test assertion**

### Rules

- **Run all Phase 4 e2e tests again** — L0 + L1 + L2 + L3
- **Don't skip** — simplify touched code. Verify the touch didn't break user-facing behavior.
- **Spec is ground truth** — when test output differs from spec, fix the code. Never change the spec to match a broken output.
- **Don't change test assertions** — if a test fails because simplify broke behavior, the test is correct and the code is wrong.
- **Debug narrowly** — the regression is a specific simplify change. Find it, fix it or revert it.
- **Loop limit** — if e2e fails more than 3 times, escalate to user: "simplify broke more than it helped. Roll back Phase 6 and proceed with original code."
- **Each loop iteration logs** what broke, what the spec says, and what fix was applied.

### State Persistence

When e2e verification loop passes:
```json
{
  "phase": "e2e-verify",
  "e2e_verify": "passed",
  "spec_alignment": "passed",
  "loop_iterations": N
}
```
