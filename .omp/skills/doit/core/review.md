# Phase 5: Review (Tool-Agnostic)

**[LOAD] [review.md](review.md) — full Phase 5 execution.**

## Phase 5 — Feature Review

After Phase 4 E2E passes, review feature delivery against spec.

### Step 1 — Diff Review

```
[[SHELL:run command="git diff --stat HEAD~1..HEAD"]]
[[SHELL:run command="git diff HEAD~1..HEAD"]]
```

Review all changes for:
- Does implementation match spec REQ criteria?
- Any REQ that was partially implemented?
- Any unexpected file changes?

### Step 2 — REQ-by-REQ Verification

For each REQ in `.spec/current.md`:
1. Check spec statement → implementation exists
2. Check tests cover the REQ
3. Check no REQ was dropped or silently changed

**Partial REQ gate:** If any REQ is partially implemented → loop back to Phase 3 for that REQ.

### Step 3 — Cross-REQ Consistency

Check for:
- Inconsistent API surface across REQs
- Contradictory behavior between REQs
- Missing integration points

**Merge duplicates gate:** If Phase 5 finds duplicate logic across REQs → merge into shared helper.
**Not Phase 6:** Phase 5 identifies duplicates, Phase 6 removes dead code and over-engineering.

### Step 4 — Code Quality Check

Quick scan for:
- Dead/unreachable code
- Unused imports
- Hardcoded values that should be configurable
- Missing error handling at system boundaries

**Phase 5 review is identification only.** Phase 6 handles the actual cleanup.

### Phase 5 Gate

Before entering Phase 6:
1. All REQs fully implemented
2. No contradictions between REQs
3. Code quality issues identified (cleanup in Phase 6)

**铁律：Phase 5 不 review = Phase 6 simplify 无目标。没确认交付完整就 simplify = 可能删掉核心逻辑。**

**[CALL] After Phase 5 complete, announce to user: `[REVIEW] Phase 5 complete — N REQs verified, M issues to simplify in Phase 6`**
