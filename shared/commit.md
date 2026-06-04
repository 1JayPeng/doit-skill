# Commit

**MANDATORY.** Do not skip. All work ends with a proper git commit and push.

## Prerequisites

Commit runs only after E2E Verification Loop passes (e2e tests all green AND spec alignment verified — output matches spec REQs).

## Steps

### 1. Check Git Status

Inspect current state and remote:

**Primary:** Use Context-Mode to index git output:
```
ctx_batch_execute(
  commands=[
    {"label": "git status", "command": "git status"},
    {"label": "git diff", "command": "git diff --staged"},
    {"label": "remote head", "command": "git log --oneline -5 origin/master"},
  ],
  queries=["changed files", "staged changes"]
)
```
- **Fallback:** If Context-Mode unavailable -> parallel Bash calls.

```bash
git status
git diff --staged
git log --oneline -5 origin/master  # check remote head
```

### 1.5. Generate Commit Context (optional, recommended)

Use TokenSave to get structured change summary:
1. `tokensave_commit_context()` — semantic summary of uncommitted changes (changed symbols, file roles, recent commit style)
2. `tokensave_changelog(from_ref="<base_branch>", to_ref="HEAD")` — if on a feature branch, structured diff between refs
3. `tokensave_pr_context(head_ref="HEAD", base_ref="<base_branch>")` — semantic diff between refs for PR description drafting
4. `tokensave_test_map(node_id="<id>")` — verify test coverage for changed symbols before committing
- **Fallback:** If TokenSave unavailable -> `git diff --name-only` + `git log --oneline` manually.

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

Do not use `git add .` — only stage files related to this feature. Include `.doit/docs/` if doc capture ran:
```bash
git add <files changed by this feature>
git add .doit/docs/  # if doc capture saved any files this session
```

Exclude:
- IDE files, build artifacts
- `.scratch/`, `.venv/`, `__pycache__/`, `node_modules/`
- `.spec/` (specs stay local, not committed to user repo)

### 4. Commit Message

**Caveman commit (optional, recommended):** If caveman skill available, run `/caveman-commit` to generate a caveman-style commit message. Falls back to manual message below.

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

## Push to Remote

### 6. Auto-Push

**Do NOT ask user. Push directly.** The workflow specifies commit + push — execute both.

Read `.doit/config.yaml` — check `commit.branch`:

**`branch` (default)** — create feature branch:
```bash
git checkout -b <prefix>/<short-description>
git push -u origin <prefix>/<short-description>
```

Prefix from config: `commit.feat_prefix` (feat), `commit.fix_prefix` (fix), `commit.refactor_prefix` (refactor).

**`current`** — push current branch:
```bash
git push -u origin HEAD
```

**`none`** — commit only, skip push.

### 7. Cleanup Intermediate Files

**After successful push, remove all workflow intermediate files.** The feature is committed + pushed. These files are no longer needed and clutter the working directory.

```bash
# Remove current spec (already archived in Phase 5 step 6)
rm -f .spec/current.md

# Remove doc-capture temp file
rm -f .spec/doc-capture.md

# Remove any other scratch artifacts
rm -rf .scratch/  # if empty
```

**What to keep:**
- `.spec/archive/` — archived specs (historical reference)
- `.doit/config.yaml` — user config (persists across runs)
- `.doit/docs/` — captured reference docs (already committed)

**What NOT to commit:**
These files are excluded from git (see step 3). Cleanup is for local directory hygiene, not git.

## Gate — Completion Summary

**After push + cleanup, BEFORE compact, present a structured completion summary to the user.** This is the last thing the user sees before context compression. Make it actionable.

### Summary Format

```
## ✅ 完成

**分支:** `origin/<branch-name>`
**提交:** `<short-hash>` — "<commit subject>"
**变更:** <N> 文件, <N> REQs 完成

### 完成内容
- REQ-001: <one-line result>
- REQ-002: <one-line result>

### 下一步
1. `<command>` — <what it does, why user runs it>
2. `<command>` — <what it does>
3. 手动测试: <specific thing to click/run/verify>
```

### Next Steps Generation Rules

**Every completion MUST give the user at least one concrete next action.** Vague "done" messages are forbidden.

Next steps are derived from the work done:

| Work Type | Next Step Template |
|-----------|-------------------|
| New feature | `./bin/<app>` or `npm start` — run the new feature |
| Bug fix | Re-run the failing case to verify fix |
| API change | Run tests: `cargo test` / `pytest` / `npm test` |
| Config change | Restart service / re-login to pick up changes |
| Documentation | `git diff origin/main...HEAD` — review PR before merge |
| Refactor | Run benchmarks: `<benchmark command>` — verify no regression |

**Command detection:** scan changed files for `Makefile`, `package.json` scripts, `Cargo.toml` `[scripts]`, `pyproject.toml` to find the project's actual run/test commands. Don't guess — use what's documented.

**Branch pushed?** Add: `git diff origin/<base>...HEAD` to review changes before merging.

**[MP-READ] Search for related project decisions (before committing):**
```
mempalace_search query="<feature> decision" wing="<project>" room="decisions" limit=3
```
Use findings to ensure commit message aligns with project decisions.

**[MP-WRITE] MemPalace persistence:**
```
mempalace_kg_add subject="<project>" predicate="shipped" object="<feature>" valid_from="<today YYYY-MM-DD>"
mempalace_diary_write agent_name="doit" entry="<commit-hash>: <feature summary>, <N> REQs, <N> files" topic="<feature>"
```

**After summary, proceed to Phase 10 Auto-Compact.** Doit session ends after compact.
