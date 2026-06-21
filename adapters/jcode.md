# Tool Adapter: jcode

Maps abstract `[[OPERATION]]` syntax to jcode native tool calls.

**jcode** (1jehuang/jcode) — Rust-based next-gen coding agent harness. Ultra-low memory (27.8MB baseline), 14ms first-frame. Built-in semantic memory, swarm (multi-agent), browser automation, self-dev mode.

## Variable Mapping

| Abstract | Value |
|----------|-------|
| `[[CONFIG:main-instructions]]` | `AGENTS.md` |
| `[[CONFIG:skill-dir]]` | `.jcode/skills/` (project) |
| `[[CONFIG:global-skill-dir]]` | `~/.jcode/skills/` (global) |
| `[[CONFIG:settings-file]]` | `~/.jcode/config.toml` |
| `[[CONFIG:mcp-config]]` | `~/.jcode/mcp.json` or `.jcode/mcp.json` |

**Compatibility fallback:** `.claude/mcp.json` is auto-imported if `~/.jcode/mcp.json` doesn't exist.

**Skill discovery:** Skills are lazy-loaded via semantic embedding matching. The agent has a `skill` tool for manual activation. Slash commands (`/doit`) also trigger skills.

## Operation Mapping

### Task Management

| Abstract | jcode |
|----------|-------|
| `[[TASK:create subject="..." description="..."]]` | No native task tool — track tasks in side panel or use swarm coordination |
| `[[TASK:update taskId="..." status="..."]]` | No native task tool — use side panel or swarm status messages |
| `[[TASK:list]]` | No native task tool — check swarm agent status |
| `[[TASK:get taskId="..."]]` | No native task tool |

**Note:** jcode doesn't have a built-in task/todo management tool. Progress tracking is done through swarm agent coordination and side panels. When using doit's task list, write tasks to `.doit/tasks.json` or display in the side panel.

### Agent (Subagent) — Swarm

| Abstract | jcode |
|----------|-------|
| `[[AGENT:spawn description="..." prompt="..." background=false]]` | `swarm(prompt: "...", headed: true)` |
| `[[AGENT:spawn description="..." prompt="..." background=true]]` | `swarm(prompt: "...", headed: false)` (headless mode) |
| `[[AGENT:spawn description="..." prompt="..." worktree=true]]` | Not directly supported — use `bash("git worktree add ...")` before swarm |
| `[[AGENT:message to="..." message="..."]]` | Swarm messaging — DM specific agent, broadcast, or repo-scoped channel |
| `[[AGENT:stop task_id="..."]]` | Swarm manages worker completion automatically |

**Usage Note:** jcode's swarm feature is powerful — it manages conflicts automatically when multiple agents edit the same repo. When agent B reads a file that agent A edited, the server notifies B with a diff. Agents can ignore or reconcile. The main agent becomes the coordinator, spawned agents become workers. Groups, messaging channels, and completion status are auto-managed.

**Swarm types:**
- `headed` — worker shows its own TUI, good for monitoring
- `headless` — worker runs in background, main coordinator handles output
- Auto-spawn — agents can spawn their own swarms autonomously

**Conflict resolution:** Native conflict detection. When code shifts under an agent's feet, the server notifies and the agent decides to ignore or check the diff.

### User Interaction

| Abstract | jcode |
|----------|-------|
| `[[USER:ask questions=[{question:"...", header:"...", options:[...]}]]]` | Interactive TUI input — ask directly, user types response |

**Usage Note:** jcode has an interactive TUI. Inputs are interleaved with the working agent by default (sent as soon as KV cache allows). Use Shift+Enter to queue input until agent finishes its turn.

### File Operations

| Abstract | jcode |
|----------|-------|
| `[[FILE:read path="..."]]` | `read("...")` |
| `[[FILE:write path="..." content="..."]]` | `write("...", "...")` |
| `[[FILE:edit path="..." old_string="..." new_string="..."]]` | `edit("...", "...", "...")` |

**Usage Note:** jcode supports side panel rendering — you can load files into the side panel for real-time monitoring, or use it as a diff viewer.

### Shell

| Abstract | jcode |
|----------|-------|
| `[[SHELL:run command="..."]]` | `bash("...")` |
| `[[SHELL:run command="..." background=true]]` | Background bash via shell execution |

**Usage Note:** Commands >=10s should run in background.

### Search

| Abstract | jcode |
|----------|-------|
| Grep for pattern | `agent_grep("...", { path: "..." })` — enhanced grep with file structure info, adaptive truncation |
| Glob pattern | `glob("...")` |

**Usage Note:** Agent grep includes file structure information (function list, displacement), helping the agent infer context without reading full files. Adaptive truncation based on what the agent has already seen saves context.

### Scheduling

| Abstract | jcode |
|----------|-------|
| `[[SCHEDULE:wakeup delaySeconds=120 prompt="..."]]` | No native support — use `bash("sleep 120 && echo '...'")` or implement via MCP |

### Skills

| Abstract | jcode |
|----------|-------|
| `[[SKILL:route target="..."]]` | `skill("...")` — manual activation; auto-loaded via semantic embedding match |

**Usage Note:** Skills are loaded on-demand via semantic vector matching against conversation embeddings. The agent can also manually activate skills with the `skill` tool or via slash commands.

### Memory

| Abstract | jcode |
|----------|-------|
| `[[MEMORY:compress]]` | Built-in semantic memory — automatic embedding per turn. Explicit memory tools available for active search/store. `headroom_compress(...)` via MCP if configured. |

**Usage Note:** jcode has built-in memory: embeds each turn/response as semantic vector, queries memory graph via cosine similarity. Memory sideagent extracts/consolidates memories periodically. Auto-consolidation via ambient mode reorganizes and checks staleness.

### Web

| Abstract | jcode |
|----------|-------|
| `[[WEB:fetch url="..."]]` | MCP-based fetch or `bash("curl ...")` |
| `[[WEB:search query="..."]]` | MCP-based search or `bash("curl ...")` |

### Browser

| Abstract | jcode |
|----------|-------|
| Browser automation | `browser` tool — built-in with actions: status, setup, open, snapshot, get_content, interactables, click, type, fill_form, select, wait, screenshot, eval, scroll, upload, press |

**Usage Note:** jcode has first-class browser automation via the `browser` tool. Setup with `jcode browser setup`.

### Planning

| Abstract | jcode |
|----------|-------|
| `[[PLAN:enter]]` | No native plan mode — use side panel for planning artifacts |
| `[[PLAN:exit]]` | No native plan mode |

## Configuration

Config file: `~/.jcode/config.toml`

Key sections:
- `[[providers.<name>.models]]` — model configuration
- `[provider] stream_idle_timeout_secs` — stream timeout
- `context_window` / `context_limit` — token limits

Environment variables:
- `JCODE_OPENAI_EXTRA_BODY` — extra request body fields (JSON string)
- `JCODE_STREAM_IDLE_TIMEOUT_SECS` — stream idle timeout

## Unique Features

| Feature | Description |
|---------|-------------|
| **Memory** | Built-in semantic memory with embedding, automatic recall, consolidation |
| **Swarm** | Multi-agent collaboration with native conflict resolution |
| **Browser** | First-class browser automation tool |
| **Self-dev** | Agent can modify its own source code, rebuild, and reload |
| **Side panel** | Auxiliary info display, real-time file monitoring, diff viewer |
| **Mermaid** | 1800x faster mermaid rendering, no browser/TS dependency |
| **Cache warm** | Warns when Anthropic cache goes cold (>5min) |
| **Session resume** | Resume sessions from claude code, codex, opencode, pi |

## Installation

```bash
# Quick install
curl -fsSL https://raw.githubusercontent.com/1jehuang/jcode/master/scripts/install.sh | bash

# macOS via Homebrew
brew tap 1jehuang/jcode
brew install jcode

# From source
git clone https://github.com/1jehuang/jcode.git
cd jcode
cargo build --release
scripts/install_release.sh
```
