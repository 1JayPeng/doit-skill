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

### Step 2 — REQ-by-REQ Verification + 偏离检查

For each REQ in `.spec/current.md`:
1. Check spec statement → implementation exists
2. Check tests cover the REQ
3. Check no REQ was dropped or silently changed
4. Classify any implementation/spec mismatch:
   - **左偏离 (encouraged):** implementation fully satisfies the REQ, improves on the spec, is integrated into the main system, and is callable from the normal path → update `.spec/current.md` to match reality.
   - **右偏离 (fix):** implementation is fake or isolated, matches only function/file names, or is unused by the normal path → loop back to Phase 3 and wire/fix it.
   - **部分偏离 (fix):** only part of the REQ is implemented → loop back to Phase 3 for the missing behavior.
   - **完全偏离/未实现 (fix):** implementation does not address the REQ, or no implementation exists → loop back to Phase 3 for that REQ.

**偏离检查 gate:** Only 左偏离 may pass Phase 5, and it must update the spec before continuing.

### Step 3 — Cross-REQ Consistency

Check for:
- Inconsistent API surface across REQs
- Contradictory behavior between REQs
- Missing integration points

**Merge duplicates gate:** If Phase 5 finds duplicate logic across REQs → merge into shared helper.
**Not Phase 6:** Phase 5 identifies duplicates, Phase 6 removes dead code and over-engineering.

**Ponytail reuse check (mandatory before Phase 6):** Run `/ponytail`. Before simplifying, check existing codebase reuse → standard library/标准库 → native platform → installed dependency → GitHub/reference implementation. If GitHub code can be borrowed/copied, prefer the smallest license-compatible copy or direct reuse, cite the source, and avoid new custom code.

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
