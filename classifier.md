# Request Classifier

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

**Action:** Full phases 1-5.

## Type B — Bug

**Signs:**
- "something is broken/wrong"
- Error messages, stack traces
- "not working as expected"
- Performance regression

**Action:** Hand off to `diagnose` skill.
