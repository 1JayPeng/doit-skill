# Tool Adapters

Maps abstract `[[OPERATION:name]]` syntax to native tool calls for each AI coding CLI.

## Supported Adapters

| Adapter | CLI | Native Tools |
|---------|-----|-------------|
| [claude-code.md](claude-code.md) | Claude Code | TaskCreate, Agent, AskUserQuestion, ... |
| [opencode.md](opencode.md) | OpenCode | todowrite, question, bash, @subagent |
| [codex.md](codex.md) | OpenAI Codex CLI | shell (all operations via shell) |
| [default.md](default.md) | Generic MCP agent | Generic fallback |

## Abstract Operations

| Operation | Description |
|-----------|-------------|
| `[[TASK:create]]` | Create a task in the session checklist |
| `[[TASK:update]]` | Update task status |
| `[[TASK:list]]` | List current tasks |
| `[[TASK:get]]` | Get task details |
| `[[TASK:stop]]` | Stop a background task |
| `[[TASK:output]]` | Get task output |
| `[[AGENT:spawn]]` | Launch a subagent |
| `[[AGENT:message]]` | Send message to running subagent |
| `[[AGENT:stop]]` | Terminate a subagent |
| `[[USER:ask]]` | Ask user a question |
| `[[FILE:read]]` | Read a file |
| `[[FILE:write]]` | Write/create a file |
| `[[FILE:edit]]` | Edit a file (search-and-replace) |
| `[[SHELL:run]]` | Execute a shell command |
| `[[SCHEDULE:wakeup]]` | Schedule a delayed wakeup |
| `[[SKILL:load]]` | Load a skill |
| `[[SKILL:route]]` | Route to a bundled skill |
| `[[PLAN:enter]]` | Enter planning mode |
| `[[PLAN:exit]]` | Exit planning mode |
| `[[MEMORY:compress]]` | Compress session context |
| `[[WEB:fetch]]` | Fetch web content |
| `[[WEB:search]]` | Search the web |

## Config Variables

| Variable | Description |
|----------|-------------|
| `[[CONFIG:main-instructions]]` | Project instructions file (CLAUDE.md / AGENTS.md) |
| `[[CONFIG:skill-dir]]` | Skills install directory |
| `[[CONFIG:global-skill-dir]]` | Global skills directory |
| `[[CONFIG:settings-file]]` | CLI settings file |
| `[[CONFIG:mcp-config]]` | MCP server config file |
| `[[CONFIG:plugins-dir]]` | Plugins directory |
