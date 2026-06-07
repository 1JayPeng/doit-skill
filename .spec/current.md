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

---

## REQ-006: Enforce mandatory tool usage in SKILL.md

**Problem:** SKILL.md describes tools as references ("See X.md") but doesn't force execution. Model skips:
- Subagent launches (0 calls despite `subagent.enabled: true`)
- MP sweep 10 parallel calls (0 executed)
- Worklog writes (0 of 9 checkpoints)
- tokensave_context (rarely called in Phase 2)

**Fix:** Add **executable enforcement** to SKILL.md phase descriptions:

| Phase | Mandatory Tool | Current Text | New Text |
|-------|---------------|--------------|----------|
| Phase 0 | MP sweep 10 calls | `[LOAD] phases.md#phase-0` | Same + "Execute ALL 10 MP calls NOW. Do not skip." |
| Phase 1 | Knowledge inject + grill | `[LOAD] phases.md#phase-1` | Same + "Call learn/inject.md search BEFORE grill questions" |
| Phase 2 | tokensave_context | `See plan.md` | "Call tokensave_context with task description BEFORE reading plan.md" |
| Phase 3 | Subagent check + worklog | `See execute.md` | "Read subagent config gate. If enabled AND multiple independent REQs, launch parallel agents. Write worklog after each REQ." |
| Phase 4-8 | Worklog | Implicit | "Write worklog after phase completion. Use agentmemory_remember > mempalace > filesystem." |
| Phase 10 | Memory write | MP diary + KG | Same + "Also write to agentmemory_remember for semantic search" |

**Key insight:** The problem is NOT missing documentation. The documentation exists. The problem is the model treats `[LOAD]` as "read for reference" not "execute these tool calls." Fix: add explicit tool call instructions in SKILL.md phase index, not just [LOAD] directives.

## REQ-007: Add worklog enforcement to execute.md

Add a worklog write template at the end of each REQ section in execute.md:

```markdown
**After completing this REQ (MANDATORY):**
1. Write worklog entry:
   - agentmemory_remember content="<worklog JSON>" (primary)
   - mempalace_add_drawer wing="<project>" room="worklog" content="<summary>" (fallback)
   - Fallback: append to .doit/worklog.json
2. If worklog write fails, announce `[WARN] worklog failed` and continue
```

## REQ-008: Add subagent decision gate to execute.md

Before Phase 3 execution, add a mandatory decision block:

```markdown
**Subagent Decision Gate (execute before first REQ):**
1. Read `.doit/config.yaml` `subagent.enabled`
2. If `true` AND spec has >= 2 independent REQs (no dependencies between them):
   - Group REQs by dependency
   - Launch independent groups as parallel agents
   - Use Conductor mode for supervision
3. If `false` OR all REQs dependent: execute sequentially
4. Announce decision: `[SUBAGENT] Mode: parallel (N agents)` or `[SUBAGENT] Mode: sequential`
```
