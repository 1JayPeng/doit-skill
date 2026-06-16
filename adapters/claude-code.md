# Tool Adapter: Claude Code

Maps abstract `[[OPERATION]]` syntax to Claude Code native tool calls.

## Variable Mapping

| Abstract | Value |
|----------|-------|
| `[[CONFIG:main-instructions]]` | `CLAUDE.md` |
| `[[CONFIG:skill-dir]]` | `.claude/skills/` |
| `[[CONFIG:global-skill-dir]]` | `$HOME/.claude/skills/` |
| `[[CONFIG:settings-file]]` | `.claude/settings.json` or `$HOME/.claude/settings.json` |
| `[[CONFIG:mcp-config]]` | `$HOME/.claude.json` |
| `[[CONFIG:plugins-dir]]` | `$HOME/.claude/plugins/` |

## Operation Mapping

### Task Management

| Abstract | Claude Code |
|----------|-----------|
| `[[TASK:create subject="..." description="..."]]` | `TaskCreate({ subject: "...", description: "..." })` |
| `[[TASK:update taskId="..." status="completed"]]` | `TaskUpdate({ taskId: "...", status: "completed" })` |
| `[[TASK:list]]` | `TaskList()` |
| `[[TASK:get taskId="..."]]` | `TaskGet({ taskId: "..." })` |
| `[[TASK:output task_id="..." block=true timeout=30000]]` | `TaskOutput({ task_id: "...", block: true, timeout: 30000 })` |
| `[[TASK:stop task_id="..."]]` | `TaskStop({ task_id: "..." })` |

### Agent (Subagent)

| Abstract | Claude Code |
|----------|-----------|
| `[[AGENT:spawn description="..." prompt="..." background=false]]` | `Agent({ description: "...", prompt: "...", run_in_background: false })` |
| `[[AGENT:spawn description="..." prompt="..." background=true]]` | `Agent({ description: "...", prompt: "...", run_in_background: true })` |
| `[[AGENT:spawn description="..." prompt="..." worktree=true]]` | `Agent({ description: "...", prompt: "...", isolation: "worktree" })` |
| `[[AGENT:message to="..." message="..."]]` | `SendMessage(to: "...", message: "...")` |
| `[[AGENT:stop task_id="..."]]` | `TaskStop({ task_id: "..." })` |

**Agent types:** `general-purpose`, `claude`, `Explore`, `Plan`, `claude-code-guide`

### User Interaction

| Abstract | Claude Code |
|----------|-----------|
| `[[USER:ask questions=[{question:"...", header:"...", options:[...]}]]]` | `AskUserQuestion({ questions: [...] })` |

### File Operations

| Abstract | Claude Code |
|----------|-----------|
| `[[FILE:read path="..."]]` | `Read({ file_path: "..." })` |
| `[[FILE:write path="..." content="..."]]` | `Write({ file_path: "...", content: "..." })` |
| `[[FILE:edit file_path="..." old_string="..." new_string="..."]]` | `Edit({ file_path: "...", old_string: "...", new_string: "..." })` |

### Shell

| Abstract | Claude Code |
|----------|-----------|
| `[[SHELL:run command="..."]]` | `Bash({ command: "..." })` |
| `[[SHELL:run command="..." background=true]]` | `Bash({ command: "...", run_in_background: true })` |

### Scheduling

| Abstract | Claude Code |
|----------|-----------|
| `[[SCHEDULE:wakeup delaySeconds=120 prompt="..."]]` | `ScheduleWakeup({ delaySeconds: 120, prompt: "...", reason: "...", prompt: "..." })` |

### Skills

| Abstract | Claude Code |
|----------|-----------|
| `[[SKILL:route target="..."]]` | `Skill({ skill: "..." })` |

### Planning

| Abstract | Claude Code |
|----------|-----------|
| `[[PLAN:enter]]` | `EnterPlanMode()` |
| `[[PLAN:exit]]` | `ExitPlanMode()` |

### Memory

| Abstract | Claude Code |
|----------|-----------|
| `[[MEMORY:compress]]` | `headroom_compress(...)` via MCP |

### Web

| Abstract | Claude Code |
|----------|-----------|
| `[[WEB:fetch url="..." prompt="..."]]` | `WebFetch({ url: "...", prompt: "..." })` |
| `[[WEB:search query="..."]]` | `WebSearch({ query: "..." })` |
