# Phase Gate Checklist

**[LOAD] This file at end of ANY phase to verify workflow completeness.**

## Type R flow (resume):
```
[x] Phase 0     Classify -> detect in-progress work
[x] Resume from detected phase -> complete remaining phases
[x] Phase 9.5     Completion Summary (user-facing)
[x] Phase 9.5.5   Knowledge Distillation (structured extraction)
[x] Phase 10      Session Summary
```

## Type Q flow (query):
```
[x] Phase 0   Classify -> Type Q
[x] Answer directly using tools — codegraph, ctx_search, ctx_read
[x] Phase 10    headroom_compress
```

## Type F flow (full):
```
[x] Phase -1    Detect Environment + Config
[x] Phase 0     Classify Request
[x] Phase 1     Spec
[x] Phase 1a      Grill: skill loaded, 5+ questions (Type F) / 3+ (Type B), checklist done, .doit/grill-summary.json
[x] Phase 1b      Spec: .spec/current.md written, branch created
[x] Phase 2     Plan (impact analysis)
[x] Phase 3     Execute (TDD per REQ)
[x] Phase 4     E2E (initial tests)
[x] Phase 5     Review
[x] Phase 6     Review + Simplify
[x] Phase 7     E2E Verification Loop
[x] Phase 8     Commit + Push
[x] Phase 9       Cleanup intermediate files
[x] Phase 9.5     Completion Summary (user-facing)
[x] Phase 9.5.5   Knowledge Distillation (structured extraction)
[x] Phase 10      Session Summary
[x] Doc Capture (if user prompt has docs)
```

## Type S flow (simple):
```
[x] Phase 0   Classify
[~] Phase -1  Skip (use env-cache.json if available, otherwise skip)
[x] Execute directly
[x] Phase 9.5     Completion Summary (user-facing)
[x] Phase 9.5.5   Knowledge Distillation (structured extraction)
[x] Phase 10      Session Summary
[x] Doc Capture (if user prompt has docs)
```

## Type B flow (bug):
```
[x] Phase 0   Classify
[x] D0-D6     Debug workflow (debug.md)
[x] Phase 8     Commit + Push
[x] Phase 9.5   Completion Summary (user-facing)
[x] Phase 9.5.5 Knowledge Distillation (structured extraction)
[x] Phase 10    Session Summary
```

## Phase Transition Rules

**After Phase 3 completes:** always continue to Phase 4. Never stop at "tests pass, done."
**After Phase 6 completes:** always continue to Phase 7. E2E verification after simplification.
**After Phase 7 completes:** always continue to Phase 8. Every feature ships committed + pushed.
**After Phase 8 completes:** always continue to Phase 9. Clean up intermediate files.
**After Phase 9 completes:** always continue to Phase 9.5. Present completion summary to user.
**After Phase 9.5 completes:** always continue to Phase 9.5.5. Extract structured knowledge.
**After Phase 9.5.5 completes:** always continue to Phase 10. Gather session statistics and preserve knowledge.

**The only valid end state is Phase 10 complete.** If you're about to say "done" or "completed" and Phase 10 has not run, you haven't finished.
