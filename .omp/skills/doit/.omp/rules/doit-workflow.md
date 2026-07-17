# OMP doit-skill Workflow Rules

## Session Management

### Continue from Session
When a session state exists in `.doit/session-state.json`:
1. Load session state
2. Resume from saved phase and task
3. Update status to "resumed"
4. Continue workflow from current phase

```bash
# Check for active session
if [ -f ".doit/session-state.json" ]; then
  bash scripts/session-state.sh continue
fi
```

### Session State Format
```json
{
  "version": "1.0",
  "created": "ISO8601",
  "updated": "ISO8601",
  "phase": 3,
  "current_task": "Phase 3 - Execute",
  "status": "in_progress",
  "omp_session_id": "session-123",
  "resume_info": "Resume from Phase 3"
}
```

## Task Management

### Use OMP todo Tool
All task operations MUST use the OMP todo tool:

```bash
# Initialize task list
todo({
  op: "init",
  list: [
    { phase: "Phase 0 - Classify", items: ["Classify request"] },
    { phase: "Phase 1 - Spec", items: ["Grill user", "Write spec"] },
    { phase: "Phase 2 - Plan", items: ["Write plan"] }
  ]
})

# Start next phase
todo({ op: "start", task: "Phase 1 - Spec" })

# Complete phase
todo({ op: "done", task: "Phase 0 - Classify" })
```

### Task Status Transitions
- `pending` → `in_progress` (when starting)
- `in_progress` → `completed` (when done)
- `in_progress` → `pending` (when switching)

## Subagent Management

### Use OMP task Tool
Subagent operations MUST use the OMP task tool:

```bash
# Spawn subagent
task({
  prompt: "Implement Phase 3 tasks",
  background: true,
  model: "slow"
})

# Background task
task({
  prompt: "Run tests",
  background: true
})
```

### Persistent Role Assignment
Since `[[AGENT:message]]` is unavailable:
1. At end of wave N, write agent state to `.doit/agent-state/<role>.md`
2. At start of wave N+1, spawn new `task()` with prompt including role context
3. This preserves role continuity across waves

## Browser Integration

### Web Research (Phase 1)
Use browser tool for web research during spec writing:

```bash
# Open URL
browser({ action: "open", url: "https://docs.example.com" })

# Extract content
browser({ action: "run", code: "const obs = await tab.observe(); return obs.elements;" })

# Close browser
browser({ action: "close" })
```

### E2E Testing (Phase 3)
Use browser tool for testing:

```bash
# Open test page
browser({ action: "open", url: "http://localhost:3000" })

# Interactive testing
browser({ action: "run", code: "await tab.click('button#submit');" })

# Take screenshot
browser({ action: "screenshot" })
```

## Compression

### Use lean-ctx MCP
All context operations MUST use lean-ctx MCP tools:

```bash
# Context overview
ctx_compose(task)

# Search
ctx_search(pattern, path)

# Read
ctx_read(path, mode)

# Edit
ctx_edit(path, old_string, new_string)

# Compress when context grows
ctx_compress()
```

## Web Search

### Use OMP web_search Tool
Network research MUST use OMP web_search tool:

```bash
# Search web
web_search({ query: "authentication best practices" })

# Fetch URL
web_fetch({ url: "https://example.com" })
```

## Memory Integration

### Use MemPalace
All memory operations MUST use MemPalace MCP:

```bash
# Add KG fact
mempalace_kg_add({
  entity: "feature_name",
  relation: "implements",
  target: "requirement"
})

# Search memory
mempalace_search({ query: "auth implementation" })

# Diary entry
mempalace_diary({
  phase: "Phase 3",
  summary: "Implemented auth feature",
  decisions: ["use JWT", "httpOnly cookies"]
})
```

## Configuration

### Model Selection
Use appropriate models for each phase:

| Phase | Model | Reason |
|-------|-------|--------|
| Phase 0 | smol | Fast classification |
| Phase 1 | slow | Deep spec writing |
| Phase 2 | plan | Architecture planning |
| Phase 3 | slow | TDD execution |
| Phase 4-9 | slow | Complex tasks |

Configuration in `~/.doit/config.yaml`:
```yaml
models:
  smol: "qwen3-0.6b"
  slow: "claude-sonnet-4-20250514"
  plan: "claude-opus-4-20250514"
```

## Error Handling

### Tool Failures
If a tool fails:
1. Retry once with same parameters
2. If still fails, try fallback tool
3. If no fallback, log error and continue

### Session State Recovery
If session state is corrupted:
1. Log warning
2. Start fresh session
3. Continue from Phase 0

## Best Practices

### Hash-Anchored Edits
OMP uses hash-anchored edits. Always:
1. Re-read file before edit if edit fails
2. Use content hashes instead of line numbers
3. Prefer LSP operations for symbol-level changes

### Persistent Workers
OMP runs persistent Python/Bun workers. For long tasks:
1. Submit to worker kernel instead of spawning new process
2. Use `background: true` for tasks ≥10s

### TUI Interaction
For user questions:
1. Output as formatted markdown block
2. Wait for user input on next turn
3. Parse response and proceed

### Headless Mode
For non-interactive mode:
1. Check for `recommended` option or default
2. If yes → use recommended option without pausing
3. If no → infer from project conventions