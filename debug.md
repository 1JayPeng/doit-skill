# Debug Workflow (Type B)

**Bug is a feature where the spec already exists.** The user told us what should happen. Something broke. Find out why, fix it, prove it's fixed.

## D0 — Diagnose (Reproduce)

**Before writing any code, reproduce the bug.**

1. **Capture the reported symptom** — exact error message, command, input that triggers it
2. **Reproduce the bug** — run the same command/input, confirm you see the same failure
3. **Narrow to the exact location** — `codegraph_context` for the affected area, trace the call path

```
[BUG] Symptom: "command X crashes with error Y"
[REPRODUCE] ✓ Confirmed — same error on input Z
[LOCATION] File: xxx.py, function: yyy, line: 42
```

**Cannot proceed without reproducing the bug.** If you can't reproduce, tell user. Don't guess.

Use `diagnose` skill for root cause analysis if needed.

## D1 — Regression Test (write BEFORE fix)

**Write a test that fails because of the bug. This is the single most important step — it prevents the bug from returning.**

1. **Write the test for the expected behavior** — what should happen, not what actually happens
2. **Run the test — it MUST fail (RED)**
3. **Verify the failure reason IS the bug** — not a test setup error

```
FAIL: test_xxx_regression — got "error Y", expected "correct output"
```

**If the test passes, your test is wrong — you wrote the test for the wrong behavior.**

## D2 — Fix (GREEN)

**Minimum change to make the regression test pass.**

1. Fix the root cause identified in D0
2. Run the regression test — it must pass (GREEN)
3. **No unrelated changes.** The fix addresses one thing: the bug.

```
PASS: test_xxx_regression
```

## D3 — E2E Verify the Fix

**Run e2e tests to verify the fix works in the real environment and doesn't break other entry points.**

1. **Run the original bug trigger in real env** — same command/input that caused the crash
2. **Verify the fix** — expected behavior, not exit code 0
3. **Run ALL e2e tests** — fix didn't break something else

**Spec alignment check**: compare actual output against the expected behavior described in the bug report. Fix works = output matches what it should have been.

<!-- D4: Shared phase. Single source of truth: shared/review-simplify.md -->
## D4 — Review + Simplify

**Shared phase. See [review-simplify.md](shared/review-simplify.md).** (This is the same file as feature flow's Phase 6.)

Check specifically for bugs:
- Is the fix the simplest possible solution?
- Does it duplicate error handling that exists elsewhere?
- Did you fix the symptom instead of the root cause?

<!-- D5: Shared phase. Single source of truth: shared/e2e-verify.md -->
## D5 — E2E Verification Loop

**Shared phase. See [shared/e2e-verify.md](shared/e2e-verify.md).** (This is the same file as feature flow's Phase 7.)

Spec alignment check compares actual output against the bug report — what the user reported should happen.

<!-- D6: Shared phase. Single source of truth: shared/commit.md -->
## D6 — Commit

**Shared phase. See [commit.md](shared/commit.md).** (This is the same file as feature flow's Phase 8.)

Commit message format: `fix: <what was broken>`

```json
{
  "phase": "committed",
  "type": "bugfix",
  "regression_test": true,
  "e2e": "passed",
  "e2e_verify": "passed",
  "spec_alignment": "passed"
}
```
