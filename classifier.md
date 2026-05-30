# Request Classifier

## Type R — Resume (blank /doit)

**Signs:**
- User types `/doit` with no arguments or whitespace-only arguments
- User types `/doit 继续` or `/doit resume`

**Action:** Do NOT start a new workflow. Check for in-progress work and resume from current phase:

1. **Check feature branch**: `git branch --show-current` — if on `feat/xxx` or `fix/xxx`, work in progress
2. **Check spec**: `.spec/current.md` exists → has spec, check REQ statuses for progress
3. **Check archive**: `.spec/archive/` has files → Phase 5+ completed
4. **Check git diff**: `git diff --stat` shows uncommitted changes → middle of a phase
5. **Check git log**: `git log --oneline -3` — recent commits may indicate last completed phase
6. **Check MemPalace** (if available): `mempalace_diary_read agent_name="doit" last_n=3`

**Report to user:** what phase you detected, what was last done, and ask "Resume from Phase N?"

If no in-progress work found → tell user "No in-progress workflow found. Type `/doit <your request>` to start a new one."

## Type S — Simple

**Signs:**
- Single file change
- Rename, typo fix, reformat
- Run a command, install a package
- Change config value

**Action:** Execute directly. Skip phases 1-5. Log to `.scratch/doit-log.jsonl`.

## Type F — Feature

**Signs:**
- New user-facing functionality
- Cross-module changes (2+ files likely)
- Behavioral change (not just cosmetic)
- Requires tests

**Action:** Full phases 1-8.

## Type B — Bug

**Signs:**
- "something is broken/wrong"
- Error messages, stack traces
- "not working as expected"
- Performance regression

**Action:** Run debug workflow D0-D6. See [debug.md](debug.md).

**Can use `diagnose` skill** for root cause analysis within D0, but must go through the full debug workflow (regression test → fix → e2e verify) before committing.
