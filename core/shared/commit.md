# Commit + Push (Tool-Agnostic)

## Phase 8 — Commit + Push

**Step 0 — Pre-Commit Gate (MANDATORY):**

```
[[SHELL:run command="git status --short"]]
[[SHELL:run command="git diff --stat"]]
[[SHELL:run command="git log --oneline -5"]]
```

**Step 1 — Learn commit style:**
```
[[SHELL:run command="git log --oneline -10"]]
```

**Step 2 — Stage files:**
```
[[SHELL:run command="git add <specific-files>"]]
```
**Don't use `git add -A`** — may include sensitive files (.env, credentials).

**Step 3 — Draft commit message:**
Follow project's commit convention:
```
type: short description

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

**Step 4 — Commit:**
```
[[SHELL:run command="git commit -m 'type: description'"]]
```

**Step 5 — Push decision:**
Read `.doit/config.yaml` — check `auto_commit.enabled`:
- `true` → push automatically
- `false` → `[[USER:ask questions=[{question:"Ready to commit and push?", header:"Commit", options:[{label:"Yes, push", description:"Push to remote"},{label:"Commit only", description:"Commit but don't push"}]]]]`

**Step 6 — Push:**
```
[[SHELL:run command="git push origin <branch>"]]
```

Read `.doit/config.yaml` — check `commit.branch`:
- `branch` → push to current branch
- `main` → push to main
