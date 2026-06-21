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

**Usage Note:** Use `run_in_background: true` for tasks >10s. When spawning multiple agents for parallel work, send them in a single message with multiple tool uses. Don't poll background agents — you'll be notified when they complete. For code research, prefer `Explore` agent type over `general-purpose`.

**Task Usage Frequency:** Claude Code has native `TaskCreate`/`TaskUpdate`/`TaskList` tools. **Call `TaskUpdate` after every sub-step**, not just at phase boundaries. A sub-step = any discrete operation (reading a file for context, running a search, implementing a REQ, running tests). If 3+ sub-steps pass without a `TaskUpdate` call, the system will warn about stale tasks — that's a violation. Keep the task list alive as a progress tracker, not a decoration.

### User Interaction

| Abstract | Claude Code |
|----------|-----------|
| `[[USER:ask questions=[{question:"...", header:"...", options:[...]}]]]` | `AskUserQuestion({ questions: [...] })` |

**Usage Note:** Batch multiple related questions into a single `AskUserQuestion` call — don't ping-pong with the user. Use `multiSelect: true` when options are not mutually exclusive. Keep options to 2-4 per question.

### File Operations

| Abstract | Claude Code |
|----------|-----------|
| `[[FILE:read path="..."]]` | `Read({ file_path: "..." })` |
| `[[FILE:write path="..." content="..."]]` | `Write({ file_path: "...", content: "..." })` |
| `[[FILE:edit file_path="..." old_string="..." new_string="..."]]` | `Edit({ file_path: "...", old_string: "...", new_string: "..." })` |

**Usage Note:** `old_string` MUST be unique in the file — if it matches 0 or 2+ times, Edit fails. Prefer `Edit` over `Write` for existing files (sends only the diff). Use `Write` only for new files or complete rewrites.

### Shell

| Abstract | Claude Code |
|----------|-----------|
| `[[SHELL:run command="..."]]` | `Bash({ command: "..." })` |
| `[[SHELL:run command="..." background=true]]` | `Bash({ command: "...", run_in_background: true })` |

**Usage Note:** Commands ≥10s MUST use `run_in_background: true`. Don't sleep or poll — you'll be notified automatically. Avoid Bash for `cat`, `head`, `tail`, `sed`, `awk` — use `Read`/`Edit`/`Write` instead.

### Scheduling

| Abstract | Claude Code |
|----------|-----------|
| `[[SCHEDULE:wakeup delaySeconds=120 prompt="..."]]` | `ScheduleWakeup({ delaySeconds: 120, prompt: "...", reason: "...", prompt: "..." })` |

### Skills

| Abstract | Claude Code |
|----------|-----------|
| `[[SKILL:route target="..."]]` | `Skill({ skill: "..." })` |

**Usage Note:** Only invoke skills that appear in the available-skills list. Don't guess skill names. Don't invoke a skill that is already running.

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

**Usage Note:** WebFetch FAILS for authenticated URLs (Google Docs, Confluence, private GitHub). Look for MCP-provided fetch tools first. WebSearch results must include sources as markdown links in the response.
