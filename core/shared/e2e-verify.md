# E2E Verification Loop (Tool-Agnostic)

## Phase 7 — E2E Verification

**The Problem:** Phase 4 E2E tests ran during dev. Phase 6 simplification may have broken things. Phase 7 verifies all REQs still work.

**Step 1 — Run full test suite:**
```
[[SHELL:run command="cargo test 2>&1 | tail -50"]]
# or
[[SHELL:run command="pytest -xvs 2>&1 | tail -50"]]
```

**Step 2 — Verify against spec REQs:**
For each REQ in `.spec/current.md`:
- [ ] REQ-specific tests pass
- [ ] REQ functionality observable
- [ ] No regression in other REQs

**Step 3 — If tests fail:**
1. Fix failure
2. Re-run tests
3. If fix needs new code → loop to Phase 3 for that REQ
4. If trivial fix → apply directly, re-run

**Step 4 — Manual verification (L2+L3):**
If L2/L3 tests require user interaction → `[[USER:ask questions=[{question:"Please verify: ...", ...}]]]`
