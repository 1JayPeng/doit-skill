# Do It — Setup Manifest

Everything `doit` depends on. Copy this to replicate the full environment.

## Global Tools

### RTK (Rust Token Killer)
Token-optimized CLI proxy. 60-90% savings on dev operations.

```bash
# Install
cargo install rtk  # or install via package manager

# Verify
rtk --version       # should show rtk X.Y.Z
rtk gain            # should work

# Global hook config (~/.claude/settings.json):
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{"type": "command", "command": "rtk hook claude"}]
    }]
  }
}
```

### Code-Review-Graph
MCP server for code knowledge graph + impact analysis. Community/architecture level.

```bash
# Launch via uvx
uvx code-review-graph

# Verify
uvx --list 2>/dev/null | grep code-review-graph

# MCP config (project-level .mcp.json):
{
  "mcpServers": {
    "code-review-graph": {
      "command": "uvx",
      "args": ["code-review-graph", "serve"],
      "cwd": "/path/to/repo",
      "type": "stdio"
    }
  }
}
```

### CodeGraph
MCP server for symbol-level code intelligence. Fast symbol lookup, caller/callee analysis.

```bash
# Initialize in project
codegraph init -i

# Verify
codegraph status

# MCP config (project-level .mcp.json):
{
  "mcpServers": {
    "codegraph": {
      "command": "codegraph",
      "args": ["mcp-stdio"],
      "cwd": "/path/to/repo",
      "type": "stdio"
    }
  }
}
```

**Tool selection guidance lives in global CLAUDE.md, not here.**

## Context-Mode Plugin

Context window management plugin. Keeps raw data in sandbox, auto-indexes output, provides semantic search. **Must be installed as a Claude Code plugin.**

```bash
# Install via npx
npx @anthropic/context-mode

# Verify
ctx doctor

# Status
ctx stats

# Search indexed content
ctx search "query here"

# Process large files
ctx execute_file path/to/file.py -- "print(FILE_CONTENT[:100])"
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

### Optional Skills (install separately)

| Skill | Purpose |
|-------|---------|
| `code-review` | Code quality review |
| `security-review` | OWASP security audit |
| `verify` | Manual behavior verification |

### External Tools (user installs)

| Tool | Install | Used In |
|------|---------|---------|
| RTK | `cargo install rtk` | Phase 3 |
| uv | `pip install uv` | Phase 3 |
| codegraph | `npx @anthropic/codegraph init` | Phase 2, 3 |
| code-review-graph | `pip install code-review-graph` | Phase 2 |
| Context-Mode | `npx @anthropic/context-mode` | Phase 1-6 |
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
