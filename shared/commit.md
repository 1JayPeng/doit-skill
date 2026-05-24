# Commit

**MANDATORY.** Do not skip. All work ends with a proper git commit and push.

## Prerequisites

Commit runs only after E2E Verification Loop passes (e2e tests all green AND spec alignment verified — output matches spec REQs).

## Steps

### 1. Check Git Status

Inspect current state and remote:
```bash
git status
git diff --staged
git log --oneline -5 origin/master  # check remote head
```

### 2. Learn Commit Message Style

Read `git log --oneline -15` from the project. Analyze the pattern:
- **Type prefix**: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`
- **Description style**: imperative or past tense? short or detailed?
- **Body usage**: common or rare?

If CLAUDE.md doesn't document the project's commit style, write it:
```
## Commit Message Convention

Format: `<type>: <short description> (<detail>)`
Types: feat | fix | refactor | docs | test | chore
Style: lowercase subject, no period, imperative tense
Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

### 3. Stage Changes

Stage all files changed by this feature/fix:
```bash
git add <files changed by this feature>
```

Do not use `git add .` — only stage files related to this feature. Exclude:
- IDE files, build artifacts
- `.scratch/`, `.spec/`, `.venv/`, `__pycache__/`, `node_modules/`

### 4. Commit Message

Write a commit message that strictly follows the project's commit style learned in Step 2.

Format:
```
<type>: <short description>

<optional body>

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

**Rules:**
- Match the tense, capitalization, and detail level of existing commits
- Subject: WHAT changed, imperative present tense
- Body (optional): WHY, not HOW
- Always append `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>`
- Use HEREDOC for multi-line messages to preserve formatting

### 5. Update Spec

Mark completed REQs in `.spec/current.md`:
```
## Summary
Status: completed

## REQ-001: <description>
Status: done
```

### 6. Update Workflow State

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

## Push to Remote

### 7. Ask User

After commit, ask the user:
- **Push to remote?** (yes/no)
- **Which branch?** (master / feature branch name)

If user confirms:
- Push to specified branch: `git push origin <branch>`
- If pushing to a new branch: `git push -u origin <branch>`

### 8. Default Behavior (No Response)

If user does not respond, **always create a new remote feature branch** and push:

1. Generate branch name from the change:
   - Feature: `feat/<short-description>`
   - Fix: `fix/<short-description>`
   - Refactor: `refactor/<short-description>`

2. Create and push:
```bash
git checkout -b <branch-name>
git push -u origin <branch-name>
```

## Gate

After push, announce:
- Branch name (remote)
- Commit hash
- Summary of changes
