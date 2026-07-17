# E2E Verification Loop (Tool-Agnostic)

## Phase 7 — E2E Verification

**The Problem:** Phase 4 E2E tests ran during dev. Phase 6 simplification may have broken things. Phase 7 verifies all REQs still work.

**Step 1 — Run full test suite:**
```
[[SHELL:run command="cargo test 2>&1 | tail -50"]]
# or
[[SHELL:run command="pytest -xvs 2>&1 | tail -50"]]
```

**Step 2 — Verify against spec REQs（Agent 扮演客户）：**

Agent 忘记自己是开发者，完全扮演客户视角验证每个 REQ：
- [ ] **客户视角**：如果我是客户，我期望看到这个行为吗？
- [ ] **客户操作**：客户从入口开始操作，能看到这个结果吗？
- [ ] **客户验收**：如果客户看到当前输出，他会满意吗？

For each REQ in `.spec/current.md`:
- [ ] REQ-specific tests pass
- [ ] REQ functionality observable from customer perspective
- [ ] No regression in other REQs

**Step 3 — If tests fail:**
1. Fix failure
2. Re-run tests
3. If fix needs new code → loop to Phase 3 for that REQ
4. If trivial fix → apply directly, re-run

**Step 4 — Manual verification (L2+L3):**
If L2/L3 tests require user interaction → `[[USER:ask questions=[{question:"Please verify: ...", ...}]]]`
