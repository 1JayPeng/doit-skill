# Tool Adapter: Default (Generic MCP Agent)

Fallback adapter for any MCP-supporting agent that doesn't have a dedicated adapter.

## Assumptions

This adapter assumes the target agent supports:
- **Shell execution** (via MCP `shell_execute` or built-in `bash`)
- **File read/write** (via MCP `read_file`, `write_file` or built-in)
- **MCP tool access** (codegraph, context-mode, mempalace, etc.)

## Variable Mapping

| Abstract | Value |
|----------|-------|
| `[[CONFIG:main-instructions]]` | `AGENTS.md` |
| `[[CONFIG:skill-dir]]` | `.ai/skills/` |
| `[[CONFIG:global-skill-dir]]` | `$HOME/.ai/skills/` |
| `[[CONFIG:settings-file]]` | `.ai/settings.json` |
| `[[CONFIG:mcp-config]]` | `$HOME/.ai/mcp.json` |
| `[[CONFIG:plugins-dir]]` | N/A |

## Operation Mapping

### Task Management

| Abstract | Default |
|----------|--------|
| `[[TASK:create subject="..." description="..."]]` | Append to `.doit/tasks.md` via shell. Use structured markdown: `- [ ] subject: description` |
| `[[TASK:update taskId="..." status="..."]]` | Edit `.doit/tasks.md` via shell (`sed`, `patch`) |
| `[[TASK:list]]` | `cat .doit/tasks.md` |

**Usage Note:** File-based task tracking. Before creating new tasks, truncate `.doit/tasks.md` to remove stale entries from previous workflows. Keep the file current — it's the only progress indicator.

### Agent (Subagent)

| Abstract | Default |
|----------|--------|
| `[[AGENT:spawn ...]]` | If MCP `create_agent` available, use it. Otherwise, describe subagent task and let user decide. |
| `[[AGENT:message ...]]` | Not available — use shared files |
| `[[AGENT:stop ...]]` | N/A |

**Usage Note:** Generic MCP agents may not support subagents natively. When `create_agent` is unavailable, describe the subagent task in the response and let the user decide how to proceed. Use shared files (`.doit/agent-communication/`) for inter-agent communication.

### User Interaction

| Abstract | Default |
|----------|--------|
| `[[USER:ask ...]]` | Output question in markdown. If MCP `prompt` available, use it. |

### File Operations

| Abstract | Default |
|----------|--------|
| `[[FILE:read path="..."]]` | Use MCP `read_file` or `cat "..."` via shell |
| `[[FILE:write path="..." content="..."]]` | Use MCP `write_file` or `cat > "..." << 'EOF'` via shell |
| `[[FILE:edit ...]]` | Use MCP `edit_file` or generate diff + `patch` via shell |

### Shell

| Abstract | Default |
|----------|--------|
| `[[SHELL:run command="..."]]` | Use MCP `shell_execute` or built-in `bash` |

**Usage Note:** Generic shell execution. Commands ≥10s should run in the background when possible. Avoid shell for file operations when MCP `read_file`/`write_file`/`edit_file` are available.

### Scheduling

| Abstract | Default |
|----------|--------|
| `[[SCHEDULE:wakeup ...]]` | Not available — use `sleep` in background shell |

### Skills / Planning / Memory

All handled via MCP tools if available. Otherwise, note as unavailable and skip gracefully.
