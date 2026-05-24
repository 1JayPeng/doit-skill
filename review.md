# Phase 5: Review

## When

Trigger after all REQs DONE + Phase 4 initial e2e tests pass.

## Steps

### 1. Code Review

Run `code-review` skill. Focus:
- Duplicate logic -> extract shared function
- Dead code -> remove
- Over-abstraction -> flatten

### 2. Architecture Check

Run `improve-codebase-architecture` skill for insight only. **Do not execute architectural refactors.** Suggest, don't break.

### 3. Security Review

Run `security-review` skill. Check OWASP top 10.

### 4. Spec Final Check

Re-read `.spec/current.md`. Every REQ must be DONE. Gaps -> flag, don't auto-fix.

### 5. Phase 6 Next (MANDATORY)

**After Phase 5 completes, you MUST run Phase 6 Review+Simplify.** See [review-simplify.md](review-simplify.md).
This is where you check your own work for:
- Code that works but is over-engineered
- Missed README/CLAUDE.md updates
- Documentation that doesn't match new behavior

**Do not proceed to Archive without Phase 6.**

### 6. Archive

All REQs DONE + Phase 6 passes + user confirms:
```bash
mv .spec/current.md .spec/archive/feature-name-$(date +%Y%m%d).md
git add .spec/
git commit -m "archive spec: feature-name"
```
