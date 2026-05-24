# Do It — Setup Manifest

Everything `doit` depends on. Copy this to replicate the full environment.

## Global Tools

### RTK (Rust Token Killer)
Token-optimized CLI proxy. 60-90% savings on dev operations. [GitHub](https://github.com/rtk-ai/rtk)

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh

# Initialize for Claude Code
rtk init -g

# Verify
rtk --version       # should show rtk X.Y.Z
rtk gain            # should work
```

### Code-Review-Graph
MCP server for code knowledge graph + impact analysis. Community/architecture level. [GitHub](https://github.com/tirth8205/code-review-graph)

```bash
# Install
uv tool install code-review-graph

# Configure for Claude Code
uvx code-review-graph install --platform claude-code

# Build index for current project
uvx code-review-graph build

# Verify
code-review-graph status
```

### CodeGraph
MCP server for symbol-level code intelligence. Fast symbol lookup, caller/callee analysis. [GitHub](https://github.com/colbymchenry/codegraph)

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh

# Initialize in project
codegraph init -i

# Verify
codegraph status
```

**Tool selection guidance lives in global CLAUDE.md, not here.**

## Context-Mode Plugin

Context window management plugin. Keeps raw data in sandbox, auto-indexes output, provides semantic search. **Must be installed as a Claude Code plugin.** [GitHub](https://github.com/mksglu/context-mode)

```bash
# Install (Claude Code v1.0.33+)
/plugin marketplace add mksglu/context-mode
/plugin install context-mode@context-mode

# Verify
/context-mode:ctx-doctor
```

**Key features:**
- `ctx_batch_execute` — run multiple commands, auto-index, search (replaces many Read/Grep calls)
- `ctx_execute_file` — process large files without loading into context
- `ctx_fetch_and_index` — fetch and index web content
- `ctx_search` — semantic search across indexed content

## Tavily MCP (Internet Search)

Remote MCP. Streamable HTTP transport — no install needed.

```jsonc
// Add to project .mcp.json (replace with your API key):
"tavily": {
  "url": "https://mcp.tavily.com/mcp/?tavilyApiKey=<your-api-key>",
  "type": "streamable-http"
}
```

## Skills Dependency Model

doit-pack uses a **bundled dependency model**. Core skills ship inside `skills/` and are installed automatically. Optional skills require separate installation.

### Bundled Skills (ship with doit-pack)

| Skill | Purpose | Used In |
|-------|---------|---------|
| `grill-me` | Idea grilling | Phase 1 |
| `tdd` | TDD loop | Phase 3 |
| `diagnose` | Bug diagnosis | Phase 0 (type B) |
| `prototype` | Throwaway prototypes | Phase 1 |
| `handoff` | Session handoff | Any phase |
| `improve-codebase-architecture` | Architecture deepening | Phase 5 |

### Built-in Claude Code Skills (no install needed)

| Skill | Purpose |
|-------|---------|
| `code-review` | Code quality review |
| `security-review` | OWASP security audit |
| `verify` | Manual behavior verification |
| `caveman` | Token-compact mode |
| `find-skills` | Discover skills |
| `write-a-skill` | Create new skills |

### External Tools (user installs)

| Tool | Install | Used In |
|------|---------|---------|
| RTK | `curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh` | Phase 3 |
| uv | `pip install uv` | Phase 3 |
| codegraph | `curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh` | Phase 2, 3 |
| code-review-graph | `uv tool install code-review-graph && uvx code-review-graph install --platform claude-code` | Phase 2 |
| Context-Mode | `/plugin marketplace add mksglu/context-mode` | Phase 1-6 |
| Tavily MCP | Remote, API key only | Phase 1 |

### Adding Dependencies

```bash
# Add a bundled skill
./scripts/add-dependency.sh <skill-name> bundled

# Add an optional skill (edit package.json)
"dependencies.optionalSkills": {
  "new-skill": "recommended"
}

# Add an external tool (edit package.json)
"dependencies.tools": {
  "new-tool": "install-command"
}
```

## Settings

### Global (~/.claude/settings.json)

```jsonc
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "<your-token>",
    "ANTHROPIC_BASE_URL": "<your-proxy-url>",
    "model": "<your-model>"
  },
  "permissions": {
    "defaultMode": "bypassPermissions"
  },
  "skipDangerousModePermissionPrompt": true,
  "theme": "dark",
  "language": "中文",
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{"type": "command", "command": "rtk hook claude"}]
    }]
  }
}
```

### Project (~/.claude/settings.json in repo)

```jsonc
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write|Bash",
      "hooks": [{
        "type": "command",
        "command": "git rev-parse --git-dir >/dev/null 2>&1 && code-review-graph update --skip-flows --repo \"/path/to/repo\" || true",
        "timeout": 30
      }]
    }],
    "SessionStart": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "git rev-parse --git-dir >/dev/null 2>&1 && code-review-graph status --repo \"/path/to/repo\" || echo 'Not a git repo, skipping'",
        "timeout": 10
      }]
    }]
  }
}
```
