# Error Handling

## Failures by Phase

### Phase 1 (Spec) Fail
Grill reveals idea is unworkable (tech infeasible, self-contradictory).

**Action:** Terminate. Tell user why. Zero code generated -> zero loss.

### Phase 3 (Execute) Fail
TDD stuck on REQ-N. Previous REQs conflict with current.

**Action:** Stop. Re-grill (back to Phase 1 partial). Discard unverified code from failed REQ. Keep passing code.

### Phase 5 (Review) Fail
Code works but has architectural/security issues.

**Action:** Retain code on branch (`feature/xxx`). Don't merge. Present options:
1. Fix the issue -> continue on same branch
2. Accept as tech debt -> mark in spec, merge with caveat
3. Re-do from scratch -> discard and re-plan

### Phase 6 (Review+Simplify) Fail
Code has duplication, over-engineering, or documentation doesn't match new behavior.

**Action:** Fix immediately — no need to go back to earlier phases. This is cleanup, not redesign. Common fixes:
1. Merge duplicated functions
2. Remove dead code / unused imports
3. Update README/CLAUDE.md to match new behavior
4. Flatten unnecessary abstractions

**Phase 6 is a self-correction step.** If you find issues here, fix them and re-run Phase 6 until it passes. Do not report to user unless you find a fundamental design flaw that requires going back to Phase 1.

### Phase 7 (Commit) Fail

Staged changes conflict or cannot be committed.

**Action:** Resolve the specific conflict (merge, rebase, or re-stage). Do not use `--no-verify` or `--force` to bypass hooks. If the commit itself reveals issues (e.g., pre-commit hook failures), fix them and retry. Do not roll back to earlier phases — this is a git operation, not a code quality issue.

## Session Recovery

Session restart with existing branch:
1. Read `.spec/current.md` from branch
2. Check REQ status table
3. Resume at first non-DONE REQ

No spec, no branch -> start fresh from Phase 0.
