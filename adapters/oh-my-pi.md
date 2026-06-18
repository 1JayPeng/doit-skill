# Tool Adapter: oh-my-pi (omp)

Maps abstract `[[OPERATION]]` syntax to oh-my-pi (omp) native tools.

**oh-my-pi** (can1357/oh-my-pi) — Terminal AI coding agent with 32 built-in tools, hash-anchored edits, LSP integration, DAP debugging. TypeScript/Bun runtime + Rust engine. 40+ model providers.

## Variable Mapping

| Abstract | Value |
|----------|-------|
| `[[CONFIG:main-instructions]]` | `AGENTS.md` |
| `[[CONFIG:skill-dir]]` | `.omp/skills/` (project), `~/.config/omp/skills/` (user) |
| `[[CONFIG:global-skill-dir]]` | `~/.config/omp/skills/` |
| `[[CONFIG:settings-file]]` | `.omp/config.json` or `~/.config/omp/config.json` |
| `[[CONFIG:mcp-config]]` | `~/.config/omp/mcp.json` |

## Operation Mapping

### Task Management

| Abstract | oh-my-pi |
|----------|---------|
| `[[TASK:create subject="..." description="..."]]` | No native task API — maintain `.doit/tasks.md` file |
| `[[TASK:update taskId="..." status="completed"]]` | Update `.doit/tasks.md` via `edit()` |
| `[[TASK:list]]` | `read(".doit/tasks.md")` |
| `[[TASK:get taskId="..."]]` | `read(".doit/tasks.md")` + parse |

**Note:** omp has no native task management. Tasks tracked in `.doit/tasks.md`:
```markdown
- [ ] Phase 0 - Classify: Classify request
- [x] Phase 1 - Spec: Done
```

### Agent (Subagent)

| Abstract | oh-my-pi |
|----------|---------|
| `[[AGENT:spawn description="..." prompt="..."]]` | `task({ prompt: "..." })` — subagent orchestration with typed results |
| `[[AGENT:spawn description="..." prompt="..." background=true]]` | `task({ prompt: "...", background: true })` |
| `[[AGENT:spawn description="..." prompt="..." worktree=true]]` | Create git worktree first, then `task({ prompt: "..." })` |
| `[[AGENT:message to="..." message="..."]]` | Not supported — use shared files for inter-agent communication |
| `[[AGENT:stop task_id="..."]]` | Not natively supported |

**Subagent features:** Isolated workers with typed results back to parent. Loopback bridge allows subagents to call read, search, task tools.

### User Interaction

| Abstract | oh-my-pi |
|----------|---------|
| `[[USER:ask questions=[{question:"...", header:"...", options:[...]}]]]` | Interactive TUI mode — output formatted question, user responds inline. Non-interactive mode: use defaults. |

**Note:** omp has interactive TUI with themes. Questions are presented in the terminal interface. In non-interactive/headless mode, use recommended defaults.

### File Operations

| Abstract | oh-my-pi |
|----------|---------|
| `[[FILE:read path="..."]]` | `read("...")` |
| `[[FILE:write path="..." content="..."]]` | `write("...", "...")` |
| `[[FILE:edit path="..." old_string="..." new_string="..."]]` | `edit("...", "...", "...")` — hash-anchored, LSP-aware |

**Note:** omp's `edit` is hash-anchored — it uses content hashes instead of line numbers, preventing concurrent agent runs from clobbering each other. LSP integration provides symbol-aware editing (rename across files, go-to-definition).

### Shell

| Abstract | oh-my-pi |
|----------|---------|
| `[[SHELL:run command="..."]]` | `bash("...")` |
| `[[SHELL:run command="..." background=true]]` | `bash("...", { background: true })` |

**Note:** omp runs persistent Python and Bun workers. Both kernels can call back into agent tools (read, search, task) over a loopback bridge.

### Search

| Abstract | oh-my-pi |
|----------|---------|
| Grep for pattern | `search("...")` — content search |
| Glob pattern | `glob("...")` |
| List directory | `list("...")` |

### LSP Operations

| Abstract | oh-my-pi |
|----------|---------|
| Go to definition | `lsp.definition(file, line, character)` |
| Find references | `lsp.references(file, line, character)` |
| Rename symbol | `lsp.rename(file, line, character, newName)` |
| Hover (documentation) | `lsp.hover(file, line, character)` |
| Code actions | `lsp.codeActions(range)` |

**Note:** 13 LSP operations available. Use instead of grep+read for symbol exploration — more accurate, faster.

### DAP Operations

| Abstract | oh-my-pi |
|----------|---------|
| Start debugging | `dap.startDebugger()` |
| Set breakpoint | `dap.setBreakpoint(file, line)` |
| Continue | `dap.continue()` |
| Step over | `dap.next()` |
| Step into | `dap.stepIn()` |
| Evaluate expression | `dap.evaluate(expr)` |

**Note:** 27 DAP operations available. Built-in debugger adapter protocol for testing.

### Scheduling

| Abstract | oh-my-pi |
|----------|---------|
| `[[SCHEDULE:wakeup delaySeconds=120 prompt="..."]]` | No native support — `bash("sleep 120 && echo 'reminder'")` |

### Skills

| Abstract | oh-my-pi |
|----------|---------|
| `[[SKILL:route target="..."]]` | Load from `.omp/skills/<...>/SKILL.md` or `~/.config/omp/skills/<...>/SKILL.md` |

**Skill discovery locations:**
| Scope | Path |
|-------|------|
| Project | `.omp/skills/<name>/SKILL.md` |
| User | `~/.config/omp/skills/<name>/SKILL.md` |

### Planning

| Abstract | oh-my-pi |
|----------|---------|
| `[[PLAN:enter]]` | Write plan to `.doit/plan.md` |
| `[[PLAN:exit]]` | N/A |

### Memory

| Abstract | oh-my-pi |
|----------|---------|
| `[[MEMORY:compress]]` | `headroom_compress(...)` via MCP if configured |

### Web

| Abstract | oh-my-pi |
|----------|---------|
| `[[WEB:fetch url="..." prompt="..."]]` | MCP `webfetch` if available, else `bash("curl -s '...'")` |
| `[[WEB:search query="..."]]` | MCP `websearch` if available, else `bash("curl ...")` |

### Browser

| Abstract | oh-my-pi |
|----------|---------|
| `[[BROWSER:navigate url="..."]]` | Built-in controllable browser surface for live docs and web testing |

**Note:** omp has a unique built-in browser surface — useful for E2E testing web applications without external tools like Puppeteer.

## Configuration

omp uses `~/.config/omp/config.json` for configuration. Key sections:

```json
{
  "model": "anthropic/claude-sonnet-4-6",
  "tools": ["read", "edit", "bash", "search", "task", "lsp", "dap"],
  "skills": {
    "enabled": ["doit", "grill-me", "tdd"]
  },
  "mcp": {}
}
```

## Model Providers

40+ providers supported: Anthropic, OpenAI, Google, DeepSeek, HuggingFace, GitHub Copilot, local models via Ollama. Use `omp --list-models` to see available models.

## Unique Features

- **Hash-anchored edits** — content-hash based editing prevents concurrent agent conflicts
- **LSP integration** — symbol-aware editing, rename across files, go-to-definition
- **DAP debugging** — built-in debugger with breakpoints, step-through, evaluation
- **Persistent workers** — Python and Bun kernels with loopback bridge to agent tools
- **Browser surface** — controllable browser for web testing and documentation
- **Themes** — customizable TUI themes
