# Tool Adapter: OpenAI Codex CLI

Maps abstract `[[OPERATION]]` syntax to OpenAI Codex CLI.

**Codex CLI** (openai/codex) — Terminal-based coding agent with `shell` as the primary native primitive. File operations via `apply_patch` (shell pattern). Full MCP support.

## Variable Mapping

| Abstract | Value |
|----------|-------|
| `[[CONFIG:main-instructions]]` | `AGENTS.md` |
| `[[CONFIG:skill-dir]]` | `.agents/skills/` (project), `~/.codex/skills/` (user) |
| `[[CONFIG:global-skill-dir]]` | `~/.codex/skills/` |
| `[[CONFIG:settings-file]]` | `config.toml` (project), `~/.codex/config.toml` (global) |
| `[[CONFIG:mcp-config]]` | `config.toml` (MCP section) |
| `[[CONFIG:plugins-dir]]` | `.codex-plugin/` |

## Operation Mapping

### Task Management

| Abstract | Codex |
|----------|-------|
| `[[TASK:create subject="..." description="..."]]` | Maintain `.doit/tasks.md` — append via `cat >> .doit/tasks.md` |
| `[[TASK:update taskId="..." status="completed"]]` | Update `.doit/tasks.md` via `sed` or `patch` |
| `[[TASK:list]]` | `cat .doit/tasks.md` |
| `[[TASK:get taskId="..."]]` | `grep -A5 "taskId" .doit/tasks.md` |

**Note:** Codex has no native task management. Tasks tracked in `.doit/tasks.md` via file edits:
```markdown
- [ ] Phase 0 - Classify: Classify request
- [x] Phase 1 - Spec: Done
```

**Task Usage Frequency:** Codex lacks native task management, relying on `.doit/tasks.md`. **Edit this file after every sub-step** using `sed` or `patch` — change `[ ]` to `[x]` as tasks complete. This file is the ONLY progress indicator. Without regular updates, the task file becomes stale and misleads resume operations.

### Agent (Subagent)

| Abstract | Codex |
|----------|-------|
| `[[AGENT:spawn description="..." prompt="..."]]` | Subagent via `shell("codex '<prompt>'")` — max 6 concurrent |
| `[[AGENT:spawn description="..." prompt="..." background=true]]` | `shell("codex '<prompt>' &")` |
| `[[AGENT:spawn description="..." prompt="..." worktree=true]]` | Create git worktree, then spawn subagent in that directory |
| `[[AGENT:message to="..." message="..."]]` | Not supported — use shared files for inter-agent communication |
| `[[AGENT:stop task_id="..."]]` | `shell("kill <pid>")` |

**Subagent details:** v0.117.0+ uses path-based addresses (`/root/agent_a`). Configurable via `config.toml` `[agents]` section. Custom agents support read-only mode, sandbox overrides.

**Usage Note:** Max 6 concurrent subagents. Use `shell("codex '<prompt>' &")` for background agents. Subagents cannot message each other directly — use shared files for inter-agent communication.

### User Interaction

| Abstract | Codex |
|----------|-------|
| `[[USER:ask questions=[...]]]` | In `suggest` mode: output markdown question for user to respond. In `auto-edit`/`auto` mode: not available. |

**Note:** Codex approval modes: `suggest`, `auto-edit`, `auto`, `always-approve`. Interactive questions only work in `suggest` mode. For non-interactive modes, use defaults or skip.

**Usage Note:** In `suggest` mode, questions render as markdown for user response. In `auto-edit` and `auto` modes, user interaction is NOT available — always provide sensible defaults. Batch questions when possible.

### File Operations

| Abstract | Codex |
|----------|-------|
| `[[FILE:read path="..."]]` | `shell("cat '...'")` or `shell("head -n N '...'")` |
| `[[FILE:write path="..." content="..."]]` | `shell("cat > '...' << 'EOF'...EOF")` |
| `[[FILE:edit path="..." old_string="..." new_string="..."]]` | Generate unified diff + `shell("patch '...'")` or `sed` |

**Note:** Codex's `apply_patch` is a shell pattern — the model constructs a diff string `{ "cmd": ["apply_patch", "*** Begin Patch..."] }`. Prefer `sed` for simple replacements.

**Usage Note:** `sed` is the simplest and most reliable file edit method for Codex. `apply_patch` works but requires properly formatted unified diffs. For simple string replacements, prefer `sed` with unique search strings.

### Shell

| Abstract | Codex |
|----------|-------|
| `[[SHELL:run command="..."]]` | `shell("...")` — primary native primitive |
| `[[SHELL:run command="..." background=true]]` | `shell("... &")` |

**Usage Note:** `shell` is the primary native primitive — most operations go through it. Commands ≥10s MUST append `&` for background execution. Don't poll background tasks.

### Scheduling

| Abstract | Codex |
|----------|-------|
| `[[SCHEDULE:wakeup delaySeconds=120 prompt="..."]]` | No native support — `shell("sleep 120 && echo 'reminder'")` |

### Skills

| Abstract | Codex |
|----------|-------|
| `[[SKILL:route target="..."]]` | Load from `~/.codex/skills/<...>/SKILL.md` or `.agents/skills/<...>/SKILL.md` |

**Skill discovery locations:**
| Scope | Path |
|-------|------|
| Project/team | `.agents/skills/<name>/SKILL.md` |
| User | `~/.codex/skills/<name>/SKILL.md` |
| Admin | `/etc/codex/skills/<name>/SKILL.md` |
| System | `~/.codex/skills/.system/` |

### Planning

| Abstract | Codex |
|----------|-------|
| `[[PLAN:enter]]` | Write plan to `.doit/plan.md` |
| `[[PLAN:exit]]` | N/A |

### Memory

| Abstract | Codex |
|----------|-------|
| `[[MEMORY:compress]]` | `headroom_compress(...)` via MCP if configured |

### Web

| Abstract | Codex |
|----------|-------|
| `[[WEB:fetch url="..."]]` | MCP `webfetch` if available, else `shell("curl -s '...'")` |
| `[[WEB:search query="..."]]` | MCP `websearch` if available, else `curl` with search API |

## Configuration

Codex uses `config.toml` for configuration. Key sections relevant to doit:

```toml
[agents]
# Subagent configuration
max_concurrent = 6

[skills]
# Enable/disable skills
doit.enabled = true

[mcp]
# MCP servers
```

## Approval Modes

| Mode | Description | Impact on doit |
|------|-------------|----------------|
| `suggest` | Shows changes for approval before applying | Full interactivity, `[[USER:ask]]` works |
| `auto-edit` | Applies edits automatically, asks for shell commands | Limited user interaction |
| `auto` | Fully automatic, no prompts | No `[[USER:ask]]` — must use defaults |
