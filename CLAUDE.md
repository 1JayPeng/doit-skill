<!-- CLAUDE.md for doit-skill development -->
## Project: doit-skill

This is the **doit-skill** development repository. It is a Claude Code skill
for spec-driven TDD workflows. When making changes to doit-skill:

1. **Install doit-skill** from this repository:
   ```bash
   cp -r . ~/.claude/skills/doit
   ```

2. **Test changes** by running `/doit` in a project that uses doit.

3. **Follow the workflow**:
   - Phase 0: Classify request
   - Phase 1: Generate spec (grill with Tavily MCP)
   - Phase 2: Plan with code graph (codegraph + code-review-graph)
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
   - Run `./scripts/install.sh --dry-run`
   - Install and test with `./scripts/install.sh`

## Commit Message Convention

**Mandatory** — every commit follows this format. Read `git log --oneline -10`
before writing a commit to match existing style.

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

**Rules:**
- Lowercase subject, imperative present tense, no trailing period
- Body (optional): WHY not HOW
- Multiple changes in one commit: separate with ` + `
- Always append `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>`

**Examples from this repo:**
- `fix: doctor.sh syntax error + install scripts preserve symlinks`
- `feat: Phase -1 environment detection, writes to CLAUDE.md`
- `docs: reorganize Install section - each method has its own update path`

## Phase 8 — Commit + Push Workflow

1. Check `git status` and `git log --oneline -10 origin/master`
2. Stage only feature-related files (never `git add .`)
3. Write commit message matching convention above
4. **Ask user: push to remote? which branch?**
5. If no response: create new branch (`feat/...` or `fix/...`) and push

## Pre-commit Checks

Before pushing changes:
1. `./scripts/install.sh --dry-run`
2. `./scripts/install.sh`
3. `ls ~/.claude/skills/doit/`
4. `ls ~/.claude/skills/grill-me/`
5. `ls ~/.claude/skills/tdd/`
