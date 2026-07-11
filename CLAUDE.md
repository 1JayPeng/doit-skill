## 语言规则

**始终使用中文回答。** 中文 caveman 模式：简洁、无废话、保留技术术语。
- 技术术语保持原文（如 function, API, token）
- 短句、碎片化表达 OK
- 不用英文客套话

## Project: doit-skill

This is the **doit-skill** development repository. It is a multi-CLI skill
for spec-driven TDD workflows. When making changes to doit-skill:

1. **Install doit-skill** in your project (`--agent` auto-detects skill dir):
   ```bash
   ./scripts/setup.sh --agent auto
   ```

2. **Test changes** by running `/doit` in a project that uses doit.

3. **Follow the workflow**:
   - Phase 0: Classify request
   - Phase 1: Generate spec (grill with Tavily MCP)
   - Phase 2: Plan with code graph (codegraph or tokensave)
   - Phase 3: Execute TDD with context-mode
   - Phase 4: E2E tests
   - Phase 5: Review
   - Phase 6: Review + Simplify (mandatory)
   - Phase 7: E2E Verification Loop
   - Phase 8: Commit + Push

4. **Update dependencies**:
   - Bundled skills in `skills/`
   - External tools in `package.json`
   - Documentation in `README.md` and `setup.md`

5. **Verify changes**:
   - Run `./scripts/setup.sh --dry-run`
   - Install and test with `./scripts/setup.sh`

## Commit Message Convention (for this repo)

This repo's style is documented here for developer reference. The actual
commit-style detection and CLAUDE.md writing is done by the skill's
Phase 8 (`core/shared/commit.md`) when run in any user project.

```
<type>: <short description>

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

| Type | Usage |
|------|-------|
| `feat` | New feature or significant change |
| `fix` | Bug fix |
| `refactor` | Code restructure without behavior change |
| `docs` | Documentation only |
| `test` | Test changes only |
| `chore` | Build, CI, dependencies, tooling |

**Examples:**
- `fix: doctor.sh syntax error + install scripts preserve symlinks`
- `feat: Phase -1 environment detection, writes to CLAUDE.md`

## Phase 8 — Commit + Push (for this repo)

When developing doit-skill locally, follow the same workflow the skill
enforces for user projects: check git status, learn commit style,
commit, and push to remote branch.

## Built-in Skills — Triple Copy Architecture

doit bundles 6 skills (grill-me, tdd, diagnose, prototype, handoff, improve-codebase-architecture). These exist in three locations:

| Location | Purpose |
|----------|---------|
| `doit/skills/` (source) | Development copy, in this repo |
| `myskill/skills/` (dev repo) | Local dev mirror, synced via `setup.sh` |
| `~/.claude/skills/<name>/` (installed) | Runtime copy, installed per user |

**Recommended management:** Edit only in `doit/skills/` (source). Run `./scripts/setup.sh` to sync to all locations. Never edit installed copies directly — they will be overwritten on reinstall.

## Pre-commit Checks

Before pushing changes:
1. `./scripts/setup.sh --dry-run`
2. `./scripts/setup.sh` (installs to skill dir per `--agent`)
3. `./scripts/doctor.sh`

## 开发仓库一致性规则

**`/home/alice/myskill/` 是 doit skill 的唯一源码仓库。** 所有对 doit skill 的修改（优化或 debug）必须在源码端进行，不能只改已安装的副本。修改后必须：1) `./scripts/setup.sh` 同步到 `~/.claude/skills/doit/`；2) `git push origin master` 推送到远程。主分支是 `master`。
