# Tool Adapter: MiMo Code

Maps abstract `[[OPERATION]]` syntax to MiMo Code native tool calls.

**MiMo Code** (XiaomiMiMo/MiMo) — Terminal-native AI coding agent by Xiaomi. TypeScript, multi-model (MiMo V2.5, Anthropic, OpenAI, etc.). Built-in task management, plan mode, subagents, MCP support. Supports Mac/Linux/Windows.

## Variable Mapping

| Abstract | Value |
|----------|-------|
| `[[CONFIG:main-instructions]]` | `AGENTS.md` |
| `[[CONFIG:skill-dir]]` | `.mimo/skills/` (project), `~/.config/mimo/skills/` (user) |
| `[[CONFIG:global-skill-dir]]` | `~/.config/mimo/skills/` |
| `[[CONFIG:settings-file]]` | `.mimo/settings.json` (project), `~/.config/mimo/settings.json` (global) |
| `[[CONFIG:mcp-config]]` | `~/.config/mimo/mcp.json` |
| `[[CONFIG:plugins-dir]]` | `~/.config/mimo/plugins/` |

## Operation Mapping

### Task Management

| Abstract | MiMo Code |
|----------|---------|
| `[[TASK:create subject="..." description="..."]]` | `todowrite({ todos: [{ content: "subject", description: "...", status: "pending" }] })` |
| `[[TASK:update taskId="..." status="completed"]]` | `todowrite({ todos: [{ content: "...", status: "completed" }] })` |
| `[[TASK:list]]` | `todowrite({ todos: [] })` (returns current list) |
| `[[TASK:get taskId="..."]]` | Not natively supported — use `todowrite` to list and search |

**Note:** MiMo `todowrite` manages todos by content matching, not by ID. To "update" a task, re-write the full todo list with updated status. Similar to OpenCode.

### Agent (Subagent)

| Abstract | MiMo Code |
|----------|---------|
| `[[AGENT:spawn description="..." prompt="..." background=false]]` | `task({ prompt: "..." })` — synchronous |
| `[[AGENT:spawn description="..." prompt="..." background=true]]` | `task({ prompt: "..." })` — async by default |
| `[[AGENT:spawn description="..." prompt="..." worktree=true]]` | Create git worktree first, then spawn subagent in that directory |
| `[[AGENT:message to="..." message="..."]]` | Not directly supported — use shared files for inter-agent communication |
| `[[AGENT:stop task_id="..."]]` | Not directly supported — user must cancel |

**Built-in subagent types:**
- `general` — full tool access, multi-step tasks
- `explore` — read-only, fast codebase exploration

**Custom subagents** via `~/.config/mimo/settings.json` with custom prompts, models, and tool permissions.

### User Interaction

| Abstract | MiMo Code |
|----------|---------|
| `[[USER:ask questions=[{question:"...", header:"...", options:[...]}]]]` | `question({ questions: [{ question: "...", header: "...", options: [...] }] })` |

**Note:** MiMo has interactive TUI mode where `question` renders selectable options. In non-interactive mode, output markdown question and use defaults.

### File Operations

| Abstract | MiMo Code |
|----------|---------|
| `[[FILE:read path="..."]]` | `read("...")` |
| `[[FILE:write path="..." content="..."]]` | `write("...", "...")` |
| `[[FILE:edit path="..." old_string="..." new_string="..."]]` | `edit("...", "...", "...")` |

**Note:** MiMo supports safe editing with conflict detection. Edits are validated before applying.

### Shell

| Abstract | MiMo Code |
|----------|---------|
| `[[SHELL:run command="..."]]` | `bash("...")` |
| `[[SHELL:run command="..." background=true]]` | `bash("...", { run_in_background: true })` |

### Search

| Abstract | MiMo Code |
|----------|---------|
| Grep for pattern | `grep("...", { path: "..." })` |
| Glob pattern | `glob("...")` |
| List directory | `list("...", { all: true })` |

### Scheduling

| Abstract | MiMo Code |
|----------|---------|
| `[[SCHEDULE:wakeup delaySeconds=120 prompt="..."]]` | No native support — `bash("sleep 120 && echo '...'")` |

### Skills

| Abstract | MiMo Code |
|----------|---------|
| `[[SKILL:route target="..."]]` | `skill("...")` — loads from `.mimo/skills/<...>/SKILL.md` |

**Skill discovery locations:**
| Scope | Path |
|-------|------|
| Project | `.mimo/skills/<name>/SKILL.md` |
| User | `~/.config/mimo/skills/<name>/SKILL.md` |

### Planning

| Abstract | MiMo Code |
|----------|---------|
| `[[PLAN:enter]]` | Built-in Plan mode — `plan({ description: "..." })` |
| `[[PLAN:exit]]` | Exit plan mode, begin implementation |

**Note:** MiMo has a native Plan mode for scoping changes before implementation. Use for Phase 2 planning.

### Memory

| Abstract | MiMo Code |
|----------|---------|
| `[[MEMORY:compress]]` | `headroom_compress(...)` via MCP if configured |

### Web

| Abstract | MiMo Code |
|----------|---------|
| `[[WEB:fetch url="..." prompt="..."]]` | MCP `webfetch` if available, else `bash("curl -s '...'")` |
| `[[WEB:search query="..."]]` | MCP `websearch` if available, else `bash("curl ...")` |

## Configuration

MiMo uses `~/.config/mimo/settings.json` for configuration:

```json
{
  "model": "mimo/mimo-v2.5-pro",
  "skills": {
    "enabled": ["doit", "grill-me", "tdd"]
  },
  "mcp": {},
  "permission": {
    "read": "allow",
    "edit": "allow",
    "bash": "allow",
    "task": "allow",
    "todowrite": "allow",
    "question": "allow",
    "skill": "allow"
  }
}
```

## Model Providers

MiMo V2.5 (default), Anthropic, OpenAI, Google, DeepSeek, local models. Configure via `~/.config/mimo/settings.json` or `/connect` command.

## Unique Features

- **Infinite Context** — lossless compression for million-line projects
- **Agent-Model Synergy** — built-in testing, review, validation loop
- **Self-Evolving System** — automatic session review and knowledge distillation
- **Voice Input** — MiMo-V2.5-ASR for hands-free coding
- **Plan Mode** — native planning before implementation
- **Desktop App** — same experience in terminal, desktop app, and IDE extensions
- **Cross-Platform** — Mac, Linux, Windows

## Installation

```bash
# Mac & Linux
curl -fsSL https://mimo.xiaomi.com/install | bash

# Windows
npm install -g @mimo-ai/cli

# Install MiMo Code
mimo code install
```
