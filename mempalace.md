# MemPalace Integration

Persistent, cross-session memory layer for the doit workflow. Complements tokensave (code graph) and context-mode (session analytics).

## When Active

MemPalace is available when `claude plugin install --scope user mempalace` has been run. Phase -1 detects availability.

## Tool Availability Check

```
mempalace_status
```

Returns `{ total_drawers, wings, rooms, protocol, aaak_dialect }`. If it errors, MemPalace is not installed — skip all MemPalace steps.

## Integration Points

### Phase -1: Environment Detection

After checking tokensave, check MemPalace:

```
mempalace_status → available
mempalace_hook_settings → configure silent_save: true, desktop_toast: false
```

Write detection result to CLAUDE.md same section as tokensave.

### Phase 1: Spec Generation

After writing `.spec/current.md`, file the spec to MemPalace:

```
mempalace_add_drawer wing="<project>" room="specs" content="<spec content>" source_file=".spec/current.md"
```

Before grilling, search for prior related specs to avoid repeating decisions:

```
mempalace_search query="<user request keywords>" wing="<project>" limit=3
```

### Phase 2: Plan

Search MemPalace for prior implementation context:

```
mempalace_search query="<feature name> implementation" wing="<project>" limit=3
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
mempalace_add_drawer wing="<project>" room="implementation" content="REQ-001: <what was done, key files changed>"
```

### Phase 5: Review

After code review completes, file the review findings:

```
mempalace_add_drawer wing="<project>" room="reviews" content="<review summary: issues found, patterns to avoid>"
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

### Resume (Cross-Session)

When resuming a workflow across sessions, recover context:

1. Search recent diary: `mempalace_diary_read agent_name="doit" last_n=3`
2. Search project wing: `mempalace_search query="<project> <feature>" wing="<project>" limit=5`
3. Check knowledge graph: `mempalace_kg_query entity="<project>"`

This recovers what was done in prior sessions without relying on filesystem state alone.

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

## Wing and Room Convention

| Room | Content |
|------|---------|
| `specs` | Generated specs from Phase 1 |
| `decisions` | Architecture decisions (ADRs) from Phase 2 |
| `implementation` | Per-REQ implementation summaries from Phase 3 |
| `reviews` | Code review findings from Phase 5 |
| `reference-docs` | User-provided reference docs from Doc Capture |
| `bugs` | Bug diagnosis results from debug workflow |
| `e2e` | E2E test results and verification notes |

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
