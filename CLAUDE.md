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

4. **Update dependencies**:
   - Bundled skills in `skills/`
   - External tools in `package.json`
   - Documentation in `README.md` and `setup.md`

5. **Verify changes**:
   - Run `./scripts/install.sh --dry-run`
   - Install and test with `./scripts/install.sh`
