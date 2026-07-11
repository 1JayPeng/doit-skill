# Phase 4: E2E (Tool-Agnostic)

**[LOAD] [e2e.md](e2e.md) — full Phase 4 execution.**

## Phase 4 — End-to-End Tests

Phase 3 wrote unit tests per REQ. Phase 4 runs end-to-end in real environment.

### Test Levels

| Level | Scope | Execution |
|-------|-------|-----------|
| **L0** | Unit tests (existing from Phase 3) | Auto |
| **L1** | Integration tests (REQ boundaries) | Auto |
| **L2** | System tests (full feature flow) | HITL |
| **L3** | Acceptance tests (user scenarios) | HITL |

### Step 1 — L0: Re-run Unit Tests (Auto)

```
[[SHELL:run command="cargo test 2>&1 | tail -50"]]
# or
[[SHELL:run command="pytest -xvs 2>&1 | tail -50"]]
```

All Phase 3 unit tests must pass. If any fail → fix before proceeding.

### Step 2 — L1: Integration Tests (Auto)

For each REQ boundary:
```
[[SHELL:run command="cargo test --test integration 2>&1 | tail -30"]]
```

**If no integration test suite exists:** Create minimal integration test exercising REQ boundary.
**Fallback:** `[[SHELL:run]]` with real CLI/API call.

### Step 3 — L2: System Tests (HITL)

Build end-to-end test scenarios:
1. Full feature flow from user perspective
2. Error/edge cases
3. Data persistence across feature boundaries

```
[[SHELL:run command="cargo run --release -- --feature=verify 2>&1 | tail -30"]]
# or
[[SHELL:run command="curl -s http://localhost:3000/api/verify 2>&1 | tail -10"]]
```

**L2 HITL gate:** If automated L2 not possible → `[[USER:ask]]` user to verify manually.

### Step 4 — L3: Acceptance Tests (HITL)

Verify against user's original request:
```
[[USER:ask questions=[{question:"Does the feature meet your original request? Specify any issues.", header:"L3 Acceptance", options:[{label:"Yes, works as expected", description:"Feature complete"},{label:"Needs changes", description:"Describe issues"},{label:"Partial match", description:"Mostly works, some gaps"}]}]]]
```

### Step 5 — Test Report

Write test results to `.doit/e2e-report.md`:
```markdown
## E2E Report

L0 (unit): PASS/FAIL — N tests
L1 (integration): PASS/FAIL — N tests
L2 (system): PASS/FAIL — N scenarios
L3 (acceptance): PASS/FAIL — N scenarios

Failed tests: [list or "none"]
```

### Phase 4 Gate

1. L0 + L1 all pass
2. L2 + L3 verified (auto or HITL)
3. `.doit/e2e-report.md` written
4. Announced to user: `[E2E] Phase 4 complete — L0:L1 auto PASS, L2:L3 HITL verified`

**铁律：Phase 4 E2E 是 Phase 5 review 的前置。E2E 不过 = 不能进 Phase 5。**
