# Commit

**MANDATORY.** Do not skip. All work ends with a proper git commit and push.

## Prerequisites

Commit runs only after E2E Verification Loop passes (e2e tests all green AND spec alignment verified — output matches spec REQs).

## Pre-Commit Gate (MANDATORY — Execute Before Step 1)

**[CALL] This gate runs once before any commit. No skip. No rationalize.**

Before staging anything, verify the full workflow was followed:

```
[Pre-Commit Gate] Check workflow compliance:
  □ Phase 0 — Classification announced? (Type R/S/F/B visible in conversation)
  □ Phase 5 — Review completed? (review.md checklist done)
  □ Phase 6 — Simplify completed? (review-simplify.md steps executed)
  □ Phase 7 — E2E Verification Loop passed? (e2e-verify.md flow completed)

**[CALL] LSP Diagnostic Gate (MANDATORY):**
Fallback: `cargo check`, `tsc --noEmit`, `pyright`.
**No dirty type-check = no commit.**
```

**If ANY box is unchecked:**
1. **STOP. Do not commit.**
2. Announce which phases are missing: `[PRE-COMMIT GATE] Missing: Phase X (description)`
3. Execute the missing phase(s) NOW
4. Re-run this gate
5. Only proceed when ALL boxes are checked

**铁律: 没有通过 Pre-Commit Gate = 禁止 commit。跳过 Review 直接 commit = 工作流违规。**

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

### 1.5. Generate Commit Context

Use `git diff` for structured change summary:
```bash
git diff --name-only
git log --oneline -10
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

Read `.doit/config.yaml` — check `auto_commit.enabled`:

**`auto_commit.enabled: true`** — Do NOT ask user. Commit and push directly.

**`auto_commit.enabled: false` (default)** — Ask user for confirmation before commit + push:
```
[[USER:ask question="Ready to commit and push?" header="Commit" options=[...]]]
```
If user says "Not yet" → skip commit and push, continue to Phase 9 cleanup.

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

**Language Rule:** The completion summary MUST be written in the user's configured language (default: Chinese/中文). Internal work process, reasoning, and tool calls can use English. Only the user-facing output (summary, next steps, REQ results) uses the user's language.

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

**[MP-WRITE] MemPalace persistence — KG mandatory (铁律):**

Check KG status first: `mempalace_kg_stats`. If `entities: 0`, you MUST populate it.

**KG facts to add (at minimum):**
```
mempalace_kg_add subject="<project>" predicate="shipped" object="<feature name>" valid_from="<today YYYY-MM-DD>"
```

**Additional KG facts (add if applicable):**
```
mempalace_kg_add subject="<project>" predicate="uses" object="<key technology/framework>" valid_from="<today YYYY-MM-DD>"
mempalace_kg_add subject="<feature>" predicate="part_of" object="<project>" valid_from="<today YYYY-MM-DD>"
mempalace_kg_add subject="<project>" predicate="has_decision" object="<decision summary>" valid_from="<today YYYY-MM-DD>"
mempalace_kg_add subject="<project>" predicate="has_api" object="<api name>" valid_from="<today YYYY-MM-DD>"
mempalace_kg_add subject="<project>" predicate="has_db" object="<db schema>" valid_from="<today YYYY-MM-DD>"
```

**Diary entry:**
```
mempalace_diary_write agent_name="doit" entry="<commit-hash>: <feature summary>, <N> REQs, <N> files" topic="<feature>"
```

**If KG stats show entities > 0 but no facts for this project:** still add the shipped fact. Every completed feature = at least one KG fact. No exceptions.

**After summary, proceed to Phase 10 Auto-Compact.** Doit session ends after compact.
