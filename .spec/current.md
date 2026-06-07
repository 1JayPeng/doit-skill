# Spec: Tool Integration Fix — Make documented tools actually work

## Problem

doit-skill documents headroom, agentmemory, lean-ctx as integrated tools, but:
- **AgentMemory MCP** was broken — used `npx -y @agentmemory/mcp` (nonexistent package) instead of `agentmemory mcp`
- **Headroom** MCP connected but only provides CCR tools (compress/retrieve), not memory management
- **Lean-ctx** wasn't installed at all
- Documentation described tool capabilities that didn't match reality

## Diagnosis Results

| Tool | MCP Tools | CLI Tools | Actual Capability |
|------|-----------|-----------|-------------------|
| context-mode | ctx_search, ctx_index, etc. | ctx_batch_execute | Session indexing + semantic search |
| mempalace | mempalace_search, add_drawer, etc. | mempalace init | Cross-session memory + KG |
| tokensave | tokensave_context, search, etc. | tokensave init | Code graph analysis |
| agentmemory | 51 MCP tools (fixed!) | agentmemory CLI | Cross-session semantic memory |
| headroom | headroom_retrieve, compress, stats | headroom memory list/export | **Proxy compression**, not memory |
| lean-ctx | lean-ctx MCP (newly installed) | lean-ctx CLI | Context window optimization |

## Fixes Applied

### 1. AgentMemory MCP — Fixed
- **Before**: `npx -y @agentmemory/mcp` (package doesn't exist)
- **After**: `agentmemory mcp` (uses installed CLI)
- **File changed**: `~/.claude/plugins/cache/rohitg00-agentmemory/agentmemory/0.9.27/.mcp.json`
- **Status**: MCP now connected, 51 tools available

### 2. Headroom — Documentation Correction
- **Reality**: Headroom MCP provides CCR (Compress-Cache-Retrieve), not memory
- **Memory CLI**: Only list/show/edit/delete/import/export — no `add` command
- **Correct usage**: Proxy compression via `ANTHROPIC_BASE_URL`, or CCR tools
- **Doc fix**: Update SKILL.md, README, phases.md to describe actual capability

### 3. Lean-ctx — Installed + Configured
- **Version**: 3.7.5
- **Location**: `~/.local/bin/lean-ctx`
- **MCP**: Connected via `lean-ctx init --agent claude`
- **Rules**: Installed at `.claude/rules/lean-ctx.md`

## REQ-001: Fix Headroom documentation

Update all references to headroom to reflect it's a **proxy compression** tool, not a memory layer.

Files to change:
- `SKILL.md` — Memory Layer section: headroom description
- `README.md` — Prerequisites table + Phase 10 tools
- `README_ZH.md` — Same
- `phases.md` — Phase 10 headroom memory commands (these don't exist!)
- `headroom.md` — Correct the Phase 10 usage examples

## REQ-002: Update Phase 10 to use real tool commands

Phase 10 currently says:
```
headroom memory add --content "<session summary>" --scope SESSION
```
This command **does not exist**. Headroom memory has no `add` command.

Correct Phase 10 should use:
- **AgentMemory**: `agentmemory_remember` MCP tool (now works!)
- **MemPalace**: `mempalace_add_drawer` MCP tool (already works)
- **Context-Mode**: `ctx_index` MCP tool (already works)
- **Headroom**: `headroom_compress` for output compression, NOT memory

## REQ-003: Update setup.sh to install lean-ctx

Add lean-ctx installation to setup.sh with fallback for network issues.

## REQ-004: Update doctor.sh to verify lean-ctx

Add lean-ctx to EXTERNAL_TOOLS and health check.

## REQ-005: Fix agentmemory MCP in setup.sh

The setup.sh currently installs agentmemory CLI but the MCP config is in the plugin directory. Document that users need to ensure the plugin's .mcp.json uses `agentmemory mcp` command.

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Headroom is proxy compression, not memory | MCP tools are compress/retrieve/stats, not memory CRUD |
| AgentMemory uses `agentmemory mcp` command | `npx -y @agentmemory/mcp` package doesn't exist |
| Lean-ctx installed via binary download | Install script may fail on network issues; binary is reliable |
| Phase 10 memory writes use agentmemory + mempalace | These have actual MCP write tools |

## Implementation Order

1. REQ-001: Fix headroom docs (headroom.md, phases.md, SKILL.md)
2. REQ-002: Fix Phase 10 commands (phases.md)
3. REQ-003: Add lean-ctx to setup.sh
4. REQ-004: Add lean-ctx to doctor.sh
5. REQ-005: Document agentmemory MCP fix
6. Update READMEs

## Out of Scope

- Making headroom do memory management (it doesn't support that via MCP)
- Installing lean-ctx via official script (network unreliable)
- Adding new tools beyond what's already documented
