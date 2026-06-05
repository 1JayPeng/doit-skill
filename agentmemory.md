# AgentMemory Integration

Cross-session semantic memory layer. Default memory provider when available.

## When Active

AgentMemory is available when `claude plugin install agentmemory` has been run and the memory server is running at `localhost:3111`.

## Installation

```bash
# Start memory server (separate terminal or background)
npx @agentmemory/agentmemory &

# Install plugin (registers 12 hooks, 4 skills, and auto-wires MCP stdio server)
claude plugin marketplace add rohitg00/agentmemory
claude plugin install agentmemory
```

Verify: `curl http://localhost:3111/agentmemory/health`
Real-time viewer: `http://localhost:3113`

## MCP Tools (53 total)

Key tools used by doit workflow:
- `memory_smart_search` — Semantic search across sessions
- `memory_save` — Persist structured memories
- `memory_sessions` — List and query session memories
- `memory_governance_delete` — Delete memories (cleanup)

## Per-Phase Integration

| Phase | AgentMemory Integration |
|-------|------------------------|
| Phase 0 | `memory_smart_search` — query project context from prior sessions |
| Phase 1 | `memory_smart_search` — find related specs, `memory_save` — save new spec |
| Phase 2 | `memory_save` — save architecture decisions |
| Phase 3 | `memory_save` — save implementation notes |
| Phase 8 | `memory_save` — save shipped feature facts |
| Phase 9.5 | `memory_save` — save knowledge extraction |
| Phase 10 | `memory_save` — save compact summary |

## Fallback

If AgentMemory is unavailable:
1. Try MemPalace MCP tools (`mempalace_status`)
2. If MemPalace also unavailable, skip all memory steps silently
3. Filesystem (`.doit/docs/`, `.spec/archive/`) remains primary persistence

## Comparison: AgentMemory vs MemPalace

| Feature | AgentMemory | MemPalace |
|---------|-------------|-----------|
| MCP tools | 53 | 30 |
| Hooks | 12 | 1 (auto-save) |
| Skills | 4 | 0 |
| Server | Required (`npx @agentmemory/agentmemory`) | Not required |
| Viewer | `localhost:3113` | None |
| Default | **Yes** | Fallback |
