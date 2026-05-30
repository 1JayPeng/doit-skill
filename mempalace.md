# MemPalace Integration

Persistent, cross-session memory layer for the doit workflow. Complements tokensave (code graph) and context-mode (session analytics).

## When Active

MemPalace is available when `claude plugin install --scope user mempalace` has been run. Phase -1 detects availability.

## Tool Availability Check

```
mempalace_status
```

Returns `{ total_drawers, wings, rooms, protocol, aaak_dialect }`. If it errors, MemPalace is not installed — skip all MemPalace steps.

After confirming availability, run maintenance:
```
mempalace_reconnect → force reconnect to palace database (refreshes in-memory HNSW index)
mempalace_sync project_dir="<project_root>" → dry-run: report stale drawers
mempalace_sync project_dir="<project_root>" apply=true → actually delete stale drawers
mempalace_get_taxonomy → full wing→room→drawer count tree (understand memory landscape)
mempalace_list_wings → list all wings (projects) with drawer counts
```

## Integration Points

### Phase -1: Environment Detection

After checking tokensave, check MemPalace:

```
mempalace_status → available
mempalace_hook_settings → configure silent_save: true, desktop_toast: false
mempalace_get_taxonomy → full wing→room→drawer count tree (understand memory landscape)
mempalace_kg_stats → knowledge graph overview (entities, triples, current_facts)
mempalace_graph_stats → palace graph overview (nodes, tunnels, edges, connectivity)
```

Write detection result to CLAUDE.md same section as tokensave.

### Phase 0: Resume (blank /doit)

When resuming, check MemPalace before filesystem:

```
mempalace_diary_read agent_name="doit" last_n=3
mempalace_search query="<project> <feature>" wing="<project>" limit=5
mempalace_kg_query entity="<project>"
mempalace_kg_timeline entity="<project>" → chronological timeline of facts about this project
mempalace_list_wings → list all wings (projects) with drawer counts
```

### Phase 1: Spec Generation

Before grilling, search for prior related specs to avoid repeating decisions:

```
mempalace_search query="<user request keywords>" wing="<project>" limit=3
mempalace_list_rooms wing="<project>" → see what rooms exist (specs, decisions, etc.)
mempalace_list_drawers wing="<project>" room="specs" limit=5 → recent specs
```

After writing `.spec/current.md`, file the spec:

```
mempalace_add_drawer wing="<project>" room="specs" content="<spec content>" source_file=".spec/current.md"
```

### Phase 2: Plan

Search MemPalace for prior implementation context:

```
mempalace_search query="<feature name> implementation" wing="<project>" limit=3
mempalace_traverse start_room="<project>/specs" max_hops=2 → find connected ideas across rooms
```

After producing the plan, store key decisions:

```
mempalace_add_drawer wing="<project>" room="decisions" content="<ADR: decision, rationale, tradeoff>"
```

### Phase 3: Execute

Before starting each REQ, check MemPalace for relevant context:

```
mempalace_search query="<REQ description>" wing="<project>" limit=2
```

After completing each REQ, file the implementation summary:

```
mempalace_add_drawer wing="<project>" room="implementation" content="REQ-00X: <what was done, key files changed>"
```

### Phase 4: E2E

After E2E tests complete, file results:

```
mempalace_add_drawer wing="<project>" room="e2e" content="Phase 4 E2E: L0+L1 passed, L2+L3 HITL pending"
```

### Phase 5: Review

After code review completes, file the review findings:

```
mempalace_add_drawer wing="<project>" room="reviews" content="<review summary: issues found, patterns to avoid>"
```

### Phase 6: Review + Simplify

If simplification changes a prior decision, update the stored drawer:

```
mempalace_list_drawers wing="<project>" room="decisions" limit=10
mempalace_get_drawer drawer_id="<id>" → fetch full content before updating
mempalace_update_drawer drawer_id="<id>" content="<updated decision>"
```

### Phase 8: Commit + Knowledge Graph

After successful commit, record the change in the knowledge graph:

```
mempalace_kg_add subject="<project>" predicate="shipped" object="<feature name>" valid_from="<today YYYY-MM-DD>"
```

If fixing a bug that invalidates a prior assumption:

```
mempalace_kg_invalidate subject="<project>" predicate="has_bug" object="<bug description>" ended="<today>"
```

### Phase 9: Cleanup + Diary

Write a diary entry summarizing the workflow:

```
mempalace_diary_write agent_name="doit" entry="Completed <feature>: <N> REQs, <N> files changed. Commit <short-hash>." topic="<feature>"
```

### Phase 10: Auto-Compact

After compact, verify MemPalace auto-save worked:

```
mempalace_memories_filed_away → { filed: true, message_count: N, timestamp: "..." }
mempalace_diary_write agent_name="doit" entry="<compact summary>" topic="compact"
```

### Doc Capture Enhancement

When capturing reference docs, also file to MemPalace (complements `.doit/docs/`):

```
mempalace_check_duplicate content="<doc content>" threshold=0.87
```

If not duplicate:

```
mempalace_add_drawer wing="<project>" room="reference-docs" content="<doc content>" source_file="<original source>"
```

### Cross-Project Work

When a feature spans multiple projects, create tunnels:

```
mempalace_create_tunnel source_wing="project_a" source_room="api" target_wing="project_b" target_room="schema" label="API contract shared between projects"
```

Explore cross-project connections:

```
mempalace_list_tunnels wing="<project>" → list all tunnels for this project
mempalace_follow_tunnels wing="<project>" room="api" → follow tunnels from a room
mempalace_find_tunnels wing_a="project_a" wing_b="project_b" → find rooms that bridge two wings
```

### Maintenance (Periodic)

When the project has been restructured or files moved:

```
mempalace_sync project_dir="<project_root>" → dry-run: report stale drawers
mempalace_sync project_dir="<project_root>" apply=true → actually delete stale drawers
mempalace_reconnect → force reconnect after external scripts modified palace
```

### Debug Workflow (Type B)

When diagnosing bugs, file diagnosis results:

```
mempalace_add_drawer wing="<project>" room="bugs" content="Bug: <description>, root cause: <X>, fix: <Y>"
```

When a bug is fixed, invalidate the prior knowledge graph fact:

```
mempalace_kg_invalidate subject="<project>" predicate="has_bug" object="<bug description>" ended="<today>"
```

## Wing and Room Convention

| Room | Content | Which Phase Writes |
|------|---------|-------------------|
| `specs` | Generated specs from Phase 1 | Phase 1 |
| `decisions` | Architecture decisions (ADRs) | Phase 2 |
| `implementation` | Per-REQ implementation summaries | Phase 3 |
| `e2e` | E2E test results and verification notes | Phase 4 |
| `reviews` | Code review findings | Phase 5 |
| `reference-docs` | User-provided reference docs | Doc Capture |
| `bugs` | Bug diagnosis results | Debug D0 |

Wing name = project root directory name (e.g., `my-project`, `doit-skill`).

## Auto-Save Hook

MemPalace has a built-in hook that auto-saves conversation context. Configure in Phase -1:

```
mempalace_hook_settings silent_save=true desktop_toast=false
```

Verify after workflow completes:

```
mempalace_memories_filed_away → { filed: true, message_count: N, timestamp: "..." }
```

## Fallback

If MemPalace is unavailable:
- All MemPalace steps are silently skipped
- Filesystem (`.doit/docs/`, `.spec/archive/`) remains the primary persistence layer
- tokensave code graph still covers code-level context
