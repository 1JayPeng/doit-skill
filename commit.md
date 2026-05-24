# Phase 7: Commit

**MANDATORY.** Do not skip. All work ends with a proper git commit.

## Prerequisites

Phase 8 runs only after Phase 7 E2E Verification Loop passes (e2e tests all green AND spec alignment verified — output matches spec REQs).

## Steps

### 1. Stage Changes

Stage all files changed by this feature:
```bash
git status
git add <files changed by this feature>
```

Do not use `git add .` — only stage files related to this feature. Exclude:
- IDE files, build artifacts
- `.scratch/`, `.spec/`, `.venv/`, `__pycache__/`, `node_modules/`

### 2. Commit Message

Write a meaningful commit message:
- Subject line: one sentence describing the WHAT
- Body (optional): WHY the change was made, not HOW

Format:
```
<type>: <short description>

<optional body>
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`

### 3. Update Spec

Mark completed REQs in `.spec/current.md`:
```
## Summary
Status: completed

## REQ-001: <description>
Status: done
```

### 4. Update Workflow State

Save to `.scratch/workflow-state.json`:
```json
{
  "phase": "committed",
  "e2e": "passed",
  "e2e_verify": "passed",
  "e2e_verify_iterations": N,
  "review": "passed"
}
```

## Gate

After commit, the workflow is complete. Announce:
- Feature branch name
- Commit hash
- Summary of changes
