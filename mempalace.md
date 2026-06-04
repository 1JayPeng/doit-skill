# MemPalace Integration

Persistent, cross-session memory layer for the doit workflow. Complements tokensave (code graph) and context-mode (session analytics).

## When Active

MemPalace is available when `claude plugin install --scope user mempalace` has been run. Phase -1 detects availability.

## Tool Availability Check

```
mempalace_status
```
Returns `{ total_drawers, wings, rooms, protocol, aaak_dialect }`. If it errors, MemPalace is not installed — skip all MemPalace steps.

## Tool Map

30 tools organized by purpose. Understanding this map prevents redundant calls.

### Read — Status & Discovery (cheap, no content)

| Tool | Returns | When to Use |
|------|---------|-------------|
| `mempalace_status` | drawer/room counts, protocol | Phase -1 availability check |
| `mempalace_list_wings` | wing -> count | Cross-project work, rare |
| `mempalace_list_rooms` | room -> count within wing | Understanding memory landscape |
| `mempalace_get_taxonomy` | full wing->room->drawer tree | Maintenance only, expensive |
| `mempalace_kg_stats` | entity/triple counts, relationship types | Diagnostic, rarely needed |
| `mempalace_graph_stats` | nodes, tunnels, edges | Diagnostic, rarely needed |
| `mempalace_hook_settings` | silent_save, desktop_toast | Phase -1 configure |
| `mempalace_memories_filed_away` | last checkpoint status | Phase 10 verify |
| `mempalace_reconnect` | reconnection result | **Before Phase 0 sweep** — refreshes HNSW index |

### Read — Content Retrieval (returns actual content, costs context)

| Tool | Returns | When to Use |
|------|---------|-------------|
| `mempalace_search` | **Full drawer content** + similarity | **Primary retrieval tool**. Use instead of list_drawers. Supports `wing`, `room`, `limit` filters. |
| `mempalace_list_drawers` | **Preview only** + pagination | When you need drawer IDs for update/delete. NOT for reading content. |
| `mempalace_get_drawer` | Full content + metadata by ID | When you have a specific drawer_id (e.g., from list_drawers) |
| `mempalace_get_aaak_spec` | AAAK compression spec | When writing compressed entries |

### Read — Knowledge Graph

| Tool | Returns | When to Use |
|------|---------|-------------|
| `mempalace_kg_query` | Entity relationships with temporal validity | Phase 0 — what facts constrain this project |
| `mempalace_kg_timeline` | Chronological fact history | Phase 0 — what was shipped, when |

### Read — Navigation

| Tool | Returns | When to Use |
|------|---------|-------------|
| `mempalace_traverse` | Connected rooms across wings | Phase 2 — find related ideas from a starting room |
| `mempalace_find_tunnels` | Rooms bridging two wings | Cross-project feature planning |
| `mempalace_list_tunnels` | All tunnels, optionally by wing | Cross-project awareness |
| `mempalace_follow_tunnels` | Connected rooms with previews | Exploring from a specific room |

### Write — Palace

| Tool | Action | When to Use |
|------|--------|-------------|
| `mempalace_add_drawer` | Store content in wing/room | Phase 1 (specs), Phase 2 (decisions), Phase 3 (implementation) |
| `mempalace_update_drawer` | Modify existing drawer | Phase 1 (spec scope change), Phase 6 (decision update) |
| `mempalace_delete_drawer` | Remove drawer (irreversible) | Cleanup, rarely |
| `mempalace_check_duplicate` | Check similarity before filing | **Before any add_drawer** to prevent duplicates |
| `mempalace_create_tunnel` | Link two wings/rooms | Cross-project features |
| `mempalace_delete_tunnel` | Remove tunnel | Cleanup |
| `mempalace_sync` | Prune stale drawers (dry-run or apply) | Periodic maintenance |

### Write — Knowledge Graph

| Tool | Action | When to Use |
|------|--------|-------------|
| `mempalace_kg_add` | Add fact (subject, predicate, object) | Phase 8 — record shipped features |
| `mempalace_kg_invalidate` | Mark fact as expired | Phase 8 — fix bugs, retire assumptions |

### Write — Agent Diary

| Tool | Action | When to Use |
|------|--------|-------------|
| `mempalace_diary_write` | Write diary entry (AAAK format recommended) | Phase 9 — workflow summary |
| `mempalace_diary_read` | Read recent entries | Phase 0 — what happened recently |

## Per-Phase Integration

Each phase document embeds its own `[MP-READ]` and `[MP-WRITE]` steps. See the phase docs for the exact calls:

| Phase | Document | MP Integration |
|-------|----------|----------------|
| Phase 0 | [SKILL.md](SKILL.md) | Full sweep: diary, KG query, KG timeline, semantic search |
| Phase 1 | [spec.md](spec.md) | `[MP-READ]` prior specs, `[MP-WRITE]` new spec |
| Phase 2 | [plan.md](plan.md) | `[MP-READ]` implementation context, `[MP-WRITE]` ADRs |
| Phase 3 | [execute.md](execute.md) | `[MP-READ]` prior implementations, `[MP-WRITE]` REQ summaries |
| Phase 4 | [e2e.md](e2e.md) | `[MP-WRITE]` E2E results |
| Phase 5 | [review.md](review.md) | `[MP-READ]` prior review findings, `[MP-WRITE]` review results |
| Phase 6 | [shared/review-simplify.md](shared/review-simplify.md) | `[MP-READ]` prior decisions, `[MP-WRITE]` updated decisions |
| Phase 8 | [shared/commit.md](shared/commit.md) | `[MP-READ]` project decisions, `[MP-WRITE]` KG facts + diary |
| Debug D0 | [debug.md](debug.md) | `[MP-READ]` prior bugs, `[MP-WRITE]` bug diagnosis |

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
mempalace_memories_filed_away -> { filed: true, message_count: N, timestamp: "..." }
```

## Optimization Rules

**1. `mempalace_search` > `mempalace_list_drawers` for content retrieval.** Search returns full content + similarity. List returns previews + requires a second `get_drawer` call for full content. Use list only when you need drawer IDs for update/delete.

**2. `mempalace_check_duplicate` before `mempalace_add_drawer`.** Prevents near-duplicate drawers from accumulating. `add_drawer` only skips exact duplicates (same deterministic ID); `check_duplicate` catches similar content at configurable threshold.

**3. Phase 0 sweep results are shared across all phases.** Don't re-query the same data in Phase 1/2. Phase 0 loads diary, KG facts, timeline, and semantic search. Phases 1-6 only do TARGETED searches for their specific needs.

**4. Parallel calls where possible.** Phase 0 Step 2: all 4 calls are independent. Run them in parallel, not sequentially. `mempalace_reconnect` must complete before search (Step 1).

**5. Keep filed content SHORT.** Implementation summaries: 2-3 lines. Diary entries: AAAK compressed format. Specs: full content is OK, they're searched for specifically.

**6. Stats tools are diagnostic, not operational.** `mempalace_get_taxonomy`, `mempalace_kg_stats`, `mempalace_graph_stats` — don't call these during normal workflow. They're for troubleshooting and maintenance.

## Fallback

If MemPalace is unavailable:
- All MemPalace steps are silently skipped
- Filesystem (`.doit/docs/`, `.spec/archive/`) remains the primary persistence layer
- tokensave code graph still covers code-level context