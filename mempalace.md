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
| `mempalace_search` | **Full drawer content** + similarity | **Primary retrieval tool**. Use instead of list_drawers. Supports `wing`, `room`, `limit`, `max_distance` filters. Always use `max_distance=0.7`. |
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
| Phase 0 | [SKILL.md](SKILL.md) | Extended sweep: diary, KG query, KG timeline, semantic search + knowledge rooms |
| Phase 1 | [spec.md](spec.md) | `[MP-READ]` prior specs + knowledge, `[MP-WRITE]` new spec |
| Phase 2 | [plan.md](plan.md) | `[MP-READ]` implementation context, `[MP-WRITE]` ADRs |
| Phase 3 | [execute.md](execute.md) | `[MP-READ]` prior implementations, `[MP-WRITE]` REQ summaries |
| Phase 4 | [e2e.md](e2e.md) | `[MP-WRITE]` E2E results |
| Phase 5 | [review.md](review.md) | `[MP-READ]` prior review findings, `[MP-WRITE]` review results |
| Phase 6 | [shared/review-simplify.md](shared/review-simplify.md) | `[MP-READ]` prior decisions, `[MP-WRITE]` updated decisions |
| Phase 8 | [shared/commit.md](shared/commit.md) | `[MP-READ]` project decisions, `[MP-WRITE]` KG facts + diary |
| Phase 9.5 | [SKILL.md](SKILL.md) | `[MP-WRITE]` knowledge extraction (code, api, db, flow) |
| Doc Capture | [doc-capture.md](doc-capture.md) | `[MP-WRITE]` knowledge_docs + reference-docs |
| Debug D0 | [debug.md](debug.md) | `[MP-READ]` prior bugs, `[MP-WRITE]` bug diagnosis |

## Wing and Room Convention

| Room | Content | Which Phase Writes |
|------|---------|-------------------|
| `specs` | Generated specs from Phase 1 | Phase 1 |
| `decisions` | Architecture decisions (ADRs) | Phase 2 |
| `implementation` | Per-REQ implementation summaries | Phase 3 |
| `e2e` | E2E test results and verification notes | Phase 4 |
| `reviews` | Code review findings | Phase 5 |
| `reference-docs` | User-provided reference docs (raw) | Doc Capture |
| `bugs` | Bug diagnosis results | Debug D0 |
| `knowledge_docs` | User feedback (migrated from sessions) | Phase 0 setup |

### Knowledge Rooms (REQ-001)

Structured knowledge extracted from sessions. These are FIRST-CLASS citizens — not secondary to filesystem.

| Room | Content | Phase Write | Phase 0 Query |
|------|---------|-------------|---------------|
| `knowledge_code` | Code patterns, implementations, reusable logic | Phase 9.5 | Type F, B |
| `knowledge_api` | API usage, endpoints, integrations | Phase 9.5 | Type F |
| `knowledge_db` | DB schemas, migrations, data models | Phase 9.5 | Type F |
| `knowledge_flow` | Data flows, architecture diagrams | Phase 9.5 | Type F |
| `knowledge_docs` | User-provided reference docs (structured) | Doc Capture | Type F |

**MP-WRITE format for knowledge rooms:** Each entry must include:
- `source_file` — where the knowledge came from
- `content` — structured summary (not raw copy-paste), 2-5 lines
- `wing` — project name

Wing name = project root directory name (e.g., `my-project`, `doit-skill`).

### Sessions Wing Strategy

The `sessions` wing has 3 rooms with different signal-to-noise ratios:

| Room | Drawers | Content | Phase 0 Action |
|------|---------|---------|----------------|
| `technical` | 3500+ | Auto-save raw conversation dumps | **Exclude** — pure noise |
| `general` | ~8 | Structured user feedback (auto-compact, etc.) | **Search** — `wing="sessions" room="general"` |
| `problems` | ~5 | Structured user feedback (no-repeat, etc.) | **Search** — `wing="sessions" room="problems"` |

**Migration:** Valuable feedback from sessions/general and sessions/problems has been migrated to `knowledge_docs` rooms in project wings. Phase 0 searches BOTH:
1. `mempalace_search wing="<project>" room="knowledge_docs"` — project-specific knowledge
2. `mempalace_search wing="sessions" room="general"` — cross-project user feedback (transition period)

**Never search `sessions/technical` without a specific reason.** It dilutes results 100x.

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

**7. ALWAYS filter by `wing` in `mempalace_search`.** The `sessions` wing (auto-save) typically contains 80-95% of all drawers and is pure noise for project context. Every `mempalace_search` MUST include `wing="<project>"`. Searching without wing filter means 90%+ of results are auto-saved session dumps.

**8. ALWAYS check `similarity` score after `mempalace_search`.** The tool returns results even when similarity is near zero. After each search:
- `similarity >= 0.3` → relevant, use the content. Note: `[MP] <N> relevant results from <wing>/<room>`
- `similarity < 0.3` → NOT relevant, treat as empty (`[]`). Do NOT use the content. Note: `[MP-EMPTY] <wing>/<room> no relevant data`
- `results: []` (empty array) → no data, proceed without MP context

**Why:** A wing with skill docs (e.g., `myskill/skills`) matches any query with similarity ~0.0-0.1. The model sees "5 results" and assumes relevance — they are not. This blocks the workflow waiting for MP context that doesn't exist.

**Fix:** Always pass `max_distance=0.7` to filter low-quality results at the tool level, AND check the returned similarity scores as a second line of defense.

**11. KG is mandatory, not optional.** `mempalace_kg_add` in Phase 8 is NOT optional. Every completed feature MUST add at least one KG fact. Empty KG (0 entities) means the project has no structured memory — Phase 0 `kg_query` and `kg_timeline` will return nothing, wasting 2 of 4 sweep calls. If KG is empty, Phase 8 MUST populate it.

**12. Sessions wing: technical = noise, general/problems = signal.** The auto-save hook writes to `sessions/technical` (3500+ drawers, raw conversation dumps — exclude). However, `sessions/general` and `sessions/problems` contain structured user feedback (auto-compact, no-repeated-actions) that applies across ALL projects. Phase 0 sweep includes `mempalace_search wing="sessions" room="general"` and `room="problems"` to capture this feedback. Do NOT search `sessions/technical`.

**13. Periodic cleanup.** When `mempalace_status` shows sessions wing > 80% of total drawers, run `mempalace_sync wing="sessions"` (dry-run first) to prune stale session drawers. This improves search quality for all projects sharing the MemPalace instance.

## Fallback

If MemPalace is unavailable:
- All MemPalace steps are silently skipped
- Filesystem (`.doit/docs/`, `.spec/archive/`) remains the primary persistence layer
- tokensave code graph still covers code-level context