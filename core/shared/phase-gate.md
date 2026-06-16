# Phase Gate Checklist (Tool-Agnostic)

Run at end of any phase to verify completeness.

## Phase Gate

```
[Phase Gate]
Current Phase: N
Next Phase: N+1

Checklist:
  [ ] Phase N tasks completed
  [ ] [[TASK:update taskId="<N>" status="completed"]] called
  [ ] Worklog entry written to .doit/worklog.json
  [ ] Tests passing (if Phase 3+)
  [ ] No iron rule violations
  [ ] [[TASK:list]] shows correct phase progression

Decision: PROCEED to Phase N+1 | BLOCK — fix issues first
```

**铁律: Phase Gate 不通过 = 不能进入下一 phase。**

## Type R flow (resume)

On resume, detect current phase from:
1. Feature branch name
2. `.spec/current.md` existence and REQ statuses
3. Git diff — uncommitted changes
4. Git log — recent commit messages
5. `[[TASK:list]]` — task status
