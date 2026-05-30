<!-- CLAUDE.md for doit-skill development -->
## Project: doit-skill

This is the **doit-skill** development repository. It is a Claude Code skill
for spec-driven TDD workflows. When making changes to doit-skill:

1. **Install doit-skill** in your project (Claude Code loads from project-local `.claude/skills/`):
   ```bash
   cp -r . .claude/skills/doit
   ```

2. **Test changes** by running `/doit` in a project that uses doit.

3. **Follow the workflow**:
   - Phase 0: Classify request
   - Phase 1: Generate spec (grill with Tavily MCP)
   - Phase 2: Plan with code graph (tokensave)
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
Phase 8 (`shared/commit.md`) when run in any user project.

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

## Pre-commit Checks

Before pushing changes:
1. `./scripts/setup.sh --dry-run`
2. `./scripts/setup.sh` (installs to `.claude/skills/` in current project)
3. `ls .claude/skills/doit/`
4. `ls .claude/skills/grill-me/`
5. `ls .claude/skills/tdd/`
