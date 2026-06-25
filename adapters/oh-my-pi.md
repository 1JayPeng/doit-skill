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
| `[[TASK:create subject="..." description="..."]]` | `todo({ op: "init", list: [{ phase: "PhaseName", items: ["task1", "task2"] }] })` |
| `[[TASK:update taskId="..." status="in_progress"]]` | `todo({ op: "start", task: "..." })` |
| `[[TASK:update taskId="..." status="completed"]]` | `todo({ op: "done", task: "..." })` |
| `[[TASK:update taskId="..." status="deleted"]]` | `todo({ op: "drop", task: "..." })` or `todo({ op: "rm", task: "..." })` |
| `[[TASK:list]]` | `todo({ op: "view" })` |
| `[[TASK:get taskId="..."]]` | `todo({ op: "view" })` + parse result |
| Append tasks to phase | `todo({ op: "append", phase: "PhaseName", items: ["task"] })` |

**Note:** OMP has a native `todo` tool (`TodoTool`, `name: "todo"`) with full CRUD support. Task identification uses the **task content string** (not a numeric ID). The `todo()` API maps 1:1 with doit's workflow operations.

**Doit → OMP mapping:**
| doit workflow | OMP `todo()` call |
|---|---|
| Phase 0: create task list | `todo({ op: "init", list: [{ phase: "OMP Adaptation", items: ["Phase 0 - Classify", "Phase 1 - Spec", ...] }] })` |
| Phase boundary: start next | `todo({ op: "start", task: "Phase 1 - Spec" })` |
| Phase boundary: complete | `todo({ op: "done", task: "Phase 0 - Classify" })` |
| Cleanup stale tasks | `todo({ op: "rm" })` (clears all) or `todo({ op: "drop", task: "..." })` |

**TUI rendering:** OMP renders the todo list in a sticky side panel. Completed tasks show with strikethrough. The panel auto-collapses phases not touched by the current operation to reduce visual noise.

**Task Usage Frequency:** Call `todo({ op: "done" })` immediately after completing each sub-step. The sticky panel keeps progress visible. Mark `in_progress` → `completed` transitions in real time — do not batch updates to phase boundaries.

**Storage:** Tasks persist in session memory by default (`storage: "session"`). Cross-session persistence requires `storage: "memory"`. The `todo` tool handles persistence automatically — no manual file management needed.

### Agent (Subagent)

| Abstract | oh-my-pi |
|----------|---------|
| `[[AGENT:spawn description="..." prompt="..."]]` | `task({ prompt: "..." })` — subagent orchestration with typed results |
| `[[AGENT:spawn description="..." prompt="..." background=true]]` | `task({ prompt: "...", background: true })` |
| `[[AGENT:spawn description="..." prompt="..." worktree=true]]` | Create git worktree first, then `task({ prompt: "..." })` |
| `[[AGENT:message to="..." message="..."]]` | Not supported — use shared files for inter-agent communication |
| `[[AGENT:stop task_id="..."]]` | Not natively supported — agent completes on its own; to abort, spawn a new task that cleans up |

**Subagent features:** Isolated workers with typed results back to parent. Loopback bridge allows subagents to call read, search, task tools.

**Known gaps & workarounds:**

| Unavailable | Workaround | Impact |
|-------------|-----------|--------|
| `[[AGENT:message]]` — persistent role assignment | Re-spawn `task()` per wave with context from `.doit/agent-state/<role>.md` | Cannot keep subagent alive between waves. Mitigate by packing multi-step instructions into a single spawn prompt. |
| `[[AGENT:stop]]` — force terminate | No equivalent; subagent runs until completion or error | Long-running subagents cannot be cancelled externally. Design tasks with bounded scope and clear exit conditions. |
| Shared state between agents | Read/write `.doit/agent-state/` markdown files between waves | Slower than in-memory messaging but reliable across waves. |

**Persistent Role Assignment (OMP workaround):** Since `[[AGENT:message]]` is unavailable, simulate persistent roles by:
1. At end of wave N, write agent state to `.doit/agent-state/<role>.md`
2. At start of wave N+1, spawn new `task()` with prompt: "You are the <Role>. Read `.doit/agent-state/<role>.md` for context. Your next task: ..."
3. This preserves role continuity across waves without requiring message passing.

**Usage Note:** Use `task({ prompt: "..." })` for subagent orchestration. Subagents have typed results — define the return type in the prompt for better type safety. Background tasks (`background: true`) run asynchronously.

### User Interaction

| Abstract | oh-my-pi |
|----------|---------|
| `[[USER:ask questions=[{question:"...", options:[...]}]]]` | OMP has no structured ask API — render as formatted markdown in the output stream; user responds inline in the TUI |

**TUI Interactive Mode (default):**
1. Output the question as a markdown block with a clear prompt indicator, e.g.:
   ```
   ── Question ──
   What authentication method should this API use?
   (1) JWT
   (2) OAuth2
   (3) Session cookies
   >
   ```
2. Wait for user input on the next turn — the TUI captures it automatically.
3. Parse the response and proceed.

**Headless / Non-Interactive Mode (fallback):**
1. Check if the question has a `recommended` option or default value.
2. If yes → use the recommended option without pausing.
3. If no → infer from project conventions (existing code patterns, `package.json`, `.doit/config.yaml`).
4. If nothing to infer from → output the question and block; this should be rare and indicates the spec is genuinely ambiguous.

**Grill-me (Phase 1) special handling:**
- Grill questions are design-clarification questions, not user preference questions.
- In headless mode, answer grill questions from the spec file, existing code conventions, or the user's initial request — do NOT block on grill questions in headless mode.
- Only escalate to the user if the spec is missing critical information needed to proceed.

**Usage Note:** Batch multiple questions into a single markdown block when possible. Always provide a clear numbered option format so the user can respond with a single digit.

### File Operations

| Abstract | oh-my-pi |
|----------|---------|
| `[[FILE:read path="..."]]` | `read("...")` |
| `[[FILE:write path="..." content="..."]]` | `write("...", "...")` |
| `[[FILE:edit path="..." old_string="..." new_string="..."]]` | `edit("...", "...", "...")` — hash-anchored, LSP-aware |

**Note:** omp's `edit` is hash-anchored — it uses content hashes instead of line numbers, preventing concurrent agent runs from clobbering each other. LSP integration provides symbol-aware editing (rename across files, go-to-definition).

**Usage Note:** Hash-anchored edits are safer than line-number based edits — they won't drift if concurrent edits change line numbers. When `edit` fails, re-read the file first to get fresh content hashes. For symbol-level refactoring, prefer `lsp.rename()` over manual `edit()` calls.

### Shell

| Abstract | oh-my-pi |
|----------|---------|
| `[[SHELL:run command="..."]]` | `bash("...")` |
| `[[SHELL:run command="..." background=true]]` | `bash("...", { background: true })` |

**Usage Note:** Commands ≥10s MUST use `background: true`. omp runs persistent Python and Bun workers — for data processing tasks, prefer submitting to the worker kernel over spawning a new shell process.

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
| `[[LSP:definition file="..." line=N col=M]]` | `lsp.definition(file, line, character)` |
| `[[LSP:references file="..." line=N col=M]]` | `lsp.references(file, line, character)` |
| `[[LSP:rename file="..." line=N col=M new_name="..."]]` | `lsp.rename(file, line, character, newName)` |
| `[[LSP:type_definition file="..." line=N col=M]]` | `lsp.typeDefinition(file, line, character)` |
| `[[LSP:implementation file="..." line=N col=M]]` | `lsp.implementation(file, line, character)` |
| `[[LSP:hover file="..." line=N col=M]]` | `lsp.hover(file, line, character)` |
| `[[LSP:code_actions file="..." range="..."]]` | `lsp.codeActions(range)` |
| `[[LSP:symbols file="..." query="..."]]` | `lsp.documentSymbol(file, query)` |

**Note:** 13 LSP operations available. Use `[[LSP:*]]` abstract operations in workflow — they resolve to `lsp.*` calls via this adapter. Prefer over grep+read for symbol exploration: more accurate, faster.

**Usage Note:** `[[LSP:rename]]` is the preferred way to refactor symbol names across files — it updates all references, imports, and exports atomically. Use `[[LSP:code_actions]]` for quick-fixes provided by the language server (import additions, unused variable removal, type fixes).

### DAP Operations

| Abstract | oh-my-pi |
|----------|---------|
| `[[DEBUG:start program="..." args=["..."]]]` | `dap.startDebugger({ program: "...", args: [...] })` |
| `[[DEBUG:breakpoint file="..." line=N]]` | `dap.setBreakpoint(file, line)` |
| `[[DEBUG:continue]]` | `dap.continue()` |
| `[[DEBUG:step_over]]` | `dap.next()` |
| `[[DEBUG:step_into]]` | `dap.stepIn()` |
| `[[DEBUG:step_out]]` | `dap.stepOut()` |
| `[[DEBUG:evaluate expr="..."]]` | `dap.evaluate(expr)` |
| `[[DEBUG:variables frame_id=N]]` | `dap.variables(frame_id)` |
| `[[DEBUG:stack_trace]]` | `dap.stackTrace()` |
| `[[DEBUG:threads]]` | `dap.threads()` |
| `[[DEBUG:terminate]]` | `dap.terminate()` |

**Note:** 27 DAP operations available. Use `[[DEBUG:*]]` abstract operations in workflow — they resolve to `dap.*` calls via this adapter. Built-in debugger adapter protocol for testing.

**Usage Note:** `[[DEBUG:start]]` launches the debuggee process; `[[DEBUG:evaluate]]` can run arbitrary expressions in the current scope. Combine `[[DEBUG:breakpoint]]` + `[[DEBUG:continue]]` for breakpoint-based debugging, or `[[DEBUG:step_into]]` / `[[DEBUG:step_over]]` for line-by-line stepping.

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
| `[[WEB:fetch url="..." prompt="..."]]` | 1. OMP built-in browser (preferred) → 2. MCP `webfetch` → 3. `bash("curl -s '...'")` |
| `[[WEB:search query="..."]]` | MCP `websearch` if available, else `bash("curl ...")` |

**Resolution chain for `[[WEB:fetch]]`:**
1. **OMP Browser** — use the built-in controllable browser surface for pages requiring JS rendering, auth, or interactive content
2. **MCP webfetch** — for static pages, JSON endpoints, or when browser is unavailable
3. **curl fallback** — last resort for simple GET requests when MCP is not configured

**Usage Note:** Prefer the browser for single-page apps, JavaScript-heavy sites, or any page that needs login. Use MCP webfetch for API endpoints and documentation pages. Only fall back to curl when both are unavailable.

### Browser

| Abstract | oh-my-pi |
|----------|---------|
| `[[BROWSER:navigate url="..."]]` | Open URL in built-in controllable browser surface |
| `[[BROWSER:click selector="..."]]` | Click element by CSS selector |
| `[[BROWSER:type selector="..." text="..."]]` | Type text into element by CSS selector |
| `[[BROWSER:fill selector="..." value="..."]]` | Fill form field by CSS selector |
| `[[BROWSER:screenshot]]` | Capture current page screenshot |
| `[[BROWSER:extract format="markdown"]]` | Extract page content as markdown or text |

**Note:** OMP has a unique built-in browser surface — useful for E2E testing web applications without external tools like Puppeteer. The browser is also the preferred mechanism for `[[WEB:fetch]]` when JS rendering is needed.

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
