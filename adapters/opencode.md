# Tool Adapter: OpenCode

Maps abstract `[[OPERATION]]` syntax to OpenCode native tool calls.

**OpenCode** (anomalyco/opencode) — Go-based AI coding CLI with 14+ built-in tools and full MCP support. Multi-model (Anthropic, OpenAI, Google, local).

## Variable Mapping

| Abstract | Value |
|----------|-------|
| `[[CONFIG:main-instructions]]` | `AGENTS.md` |
| `[[CONFIG:skill-dir]]` | `.opencode/skills/` (project) |
| `[[CONFIG:global-skill-dir]]` | `~/.config/opencode/skills/` (global) |
| `[[CONFIG:settings-file]]` | `opencode.json` (project) / `~/.config/opencode/opencode.json` (global) |
| `[[CONFIG:mcp-config]]` | `opencode.json` — `mcp` key |

**Skill discovery also checks:** `.claude/skills/`, `~/.claude/skills/`, `.agents/skills/`, `~/.agents/skills/` (compatibility mode).

## Operation Mapping

### Task Management

| Abstract | OpenCode |
|----------|---------|
| `[[TASK:create subject="..." description="..."]]` | `todowrite({ todos: [{ content: "subject", status: "pending" }] })` |
| `[[TASK:update taskId="..." status="completed"]]` | `todowrite({ todos: [{ content: "...", status: "completed" }] })` |
| `[[TASK:list]]` | `todowrite({ todos: [] })` (returns current list) |
| `[[TASK:get taskId="..."]]` | Not natively supported — use `todowrite` to list and search |

**Note:** OpenCode `todowrite` manages todos by content matching, not by ID. To "update" a task, re-write the full todo list with updated status. `todowrite` is **disabled for subagents** by default.

**Task Usage Frequency:** OpenCode's `todowrite` is the primary progress tracking mechanism. **Call `todowrite` after every sub-step** to update status. Even though OpenCode doesn't emit stale task warnings like Claude Code, maintaining an accurate todo list is essential for the user to see progress. The todo list IS the progress bar.

### Agent (Subagent)

| Abstract | OpenCode |
|----------|---------|
| `[[AGENT:spawn description="..." prompt="..." background=false]]` | `task({ agent: "general", prompt: "..." })` |
| `[[AGENT:spawn description="..." prompt="..." background=true]]` | `task({ agent: "general", prompt: "..." })` (async by default) |
| `[[AGENT:spawn description="..." prompt="..." worktree=true]]` | Create branch first, then `task({ agent: "build", prompt: "..." })` |
| `[[AGENT:message to="..." message="..."]]` | Not directly supported — spawn new subagent with context |
| `[[AGENT:stop task_id="..."]]` | Not directly supported — user must cancel |

**Built-in subagent types:**
- `general` — full tool access, multi-step tasks
- `explore` — read-only, fast codebase exploration
- `scout` — read-only, external docs / dependency research
- `build` — primary agent, all tools enabled

**Custom subagents** via `opencode.json` → `agent` key with `mode: "subagent"`. Controlled by `permission.task` with glob patterns.

**Task Usage Frequency:** OpenCode uses `todowrite` for task management. Unlike Claude Code, `todowrite` doesn't have system-level stale warnings, but **still call it after every sub-step** to maintain progress visibility. Keep the todo list current — it's the only progress tracking mechanism visible to the user.

### User Interaction

| Abstract | OpenCode |
|----------|---------|
| `[[USER:ask questions=[{question:"...", header:"...", options:[...]}]]]` | `question({ questions: [{ question: "...", header: "...", options: [...] }] })` |

### File Operations

| Abstract | OpenCode |
|----------|---------|
| `[[FILE:read path="..."]]` | `read("...")` |
| `[[FILE:write path="..." content="..."]]` | `write("...", "...")` |
| `[[FILE:edit path="..." old_string="..." new_string="..."]]` | `edit("...", "...", "...")` |
| Apply diff | `apply_patch({ patchText: "..." })` |

### Shell

| Abstract | OpenCode |
|----------|---------|
| `[[SHELL:run command="..."]]` | `bash("...")` |
| `[[SHELL:run command="..." background=true]]` | `bash("...", { run_in_background: true })` |

### Search

| Abstract | OpenCode |
|----------|---------|
| Grep for pattern | `grep("...", { path: "..." })` |
| Glob pattern | `glob("...")` |
| List directory | `list("...")` |
| LSP lookup | `lsp({ method: "textDocument/definition", textDocument: "...", position: {...} })` |

### Scheduling

| Abstract | OpenCode |
|----------|---------|
| `[[SCHEDULE:wakeup delaySeconds=120 prompt="..."]]` | No native support — use `bash("sleep 120 && echo '...'")` or implement via MCP |

### Skills

| Abstract | OpenCode |
|----------|---------|
| `[[SKILL:route target="..."]]` | `skill("...")` — loads from `.opencode/skills/<...>/SKILL.md` |

### Memory

| Abstract | OpenCode |
|----------|---------|
| `[[MEMORY:compress]]` | `headroom_compress(...)` via MCP |

### Web

| Abstract | OpenCode |
|----------|---------|
| `[[WEB:fetch url="..."]]` | `webfetch("...")` |
| `[[WEB:search query="..."]]` | `websearch("...")` |

## Permission System

OpenCode uses `opencode.json` → `permission` key. Key permissions relevant to doit:

```json
{
  "permission": {
    "read": "allow",
    "edit": "allow",        // write, edit, apply_patch
    "bash": "allow",
    "task": "allow",        // subagent spawning
    "todowrite": "allow",   // task management
    "question": "allow",    // user interaction
    "skill": "allow",       // skill loading
    "webfetch": "ask",
    "websearch": "ask"
  }
}
```
