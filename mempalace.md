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
| `mempalace_list_wings` | wing → count | Cross-project work, rare |
| `mempalace_list_rooms` | room → count within wing | Understanding memory landscape |
| `mempalace_get_taxonomy` | full wing→room→drawer tree | Maintenance only, expensive |
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
|------|---------|-------------|
| `mempalace_kg_add` | Add fact (subject, predicate, object) | Phase 8 — record shipped features |
| `mempalace_kg_invalidate` | Mark fact as expired | Phase 8 — fix bugs, retire assumptions |

### Write — Agent Diary

| Tool | Action | When to Use |
|------|---------|-------------|
| `mempalace_diary_write` | Write diary entry (AAAK format recommended) | Phase 9 — workflow summary |
| `mempalace_diary_read` | Read recent entries | Phase 0 — what happened recently |

## Integration Points

### Phase -1: Environment Detection

**Minimal check.** Just confirm availability and configure hooks. Do NOT run stats tools here — they waste tokens and the data isn't used by subsequent phases.

```
mempalace_status → available?
mempalace_hook_settings silent_save=true desktop_toast=false → configure
```

Write detection result to CLAUDE.md same section as tokensave.

**Do NOT call here:** `mempalace_get_taxonomy`, `mempalace_kg_stats`, `mempalace_graph_stats`, `mempalace_list_wings`. These are diagnostic tools that don't inform the workflow. Phase 0's sweep returns all the context that matters.

### Phase 0: Memory Context Sweep (ALL types, before any phase runs)

**After classification, BEFORE any phase logic executes.** This is the single most important MemPalace interaction — it loads the project's entire history into context so Phase 1 grilling and Phase 2 planning are informed by prior work.

**Step 1 — Refresh index (sequential, must complete first):**
```
mempalace_reconnect → ensures HNSW index is fresh after any external modifications
```

**Step 2 — Core context (ALL in parallel, no dependencies between them):**
```
# A) Recent activity — what was done in last sessions
mempalace_diary_read agent_name="doit" last_n=5

# B) Project knowledge graph — facts, constraints, decisions
mempalace_kg_query entity="<project>"

# C) Project timeline — chronological history of shipped features
mempalace_kg_timeline entity="<project>"

# D) Semantic search — finds relevant content across ALL rooms
mempalace_search query="<user request keywords>" wing="<project>" limit=5
```

**Why 4 calls instead of 7+:** `mempalace_search` returns full drawer content with similarity scores across all rooms. It replaces `mempalace_list_drawers` calls for bugs, decisions, and implementation — those were returning previews anyway. The search finds the MOST RELEVANT content, not just the most recent. `mempalace_list_rooms` is unnecessary because the search results show which rooms have content.

**Type-specific additions (also parallel):**

**Type R (resume)** — recover in-progress work:
```
mempalace_search query="<project> resume in-progress" wing="<project>" limit=3
```

**Type B (bug)** — find related prior bugs:
```
mempalace_search query="<bug keywords> error" wing="<project>" room="bugs" limit=5
```

**Type S (simple)** — skip the sweep entirely. Simple changes don't need deep context.

**Why `mempalace_reconnect` before search:** External scripts, CLI commands, or other sessions can modify the palace directly. Without reconnect, the in-memory HNSW index may be stale and search returns outdated results. This is especially important after `mempalace mine` or `mempalace compress` CLI operations.

### Phase 1: Spec Generation

Context sweep already ran. Use its results for targeted grilling.

**Before grilling — check for directly related prior specs:**
```
mempalace_search query="<user request keywords>" wing="<project>" room="specs" limit=3
```

**After writing `.spec/current.md` — file to MemPalace:**
```
# Check for duplicates first (spec may have been filed in prior session)
mempalace_check_duplicate content="<spec content>" threshold=0.87

# If not duplicate, file it
mempalace_add_drawer wing="<project>" room="specs" content="<spec content>" source_file=".spec/current.md"

# If scope changes during grill and related spec exists, update instead:
mempalace_update_drawer drawer_id="<id from check_duplicate>" content="<updated spec content>"
```

**Why `mempalace_check_duplicate` before `add_drawer`:** `mempalace_add_drawer` silently skips identical content (same deterministic drawer ID), but SIMILAR content (e.g., updated spec from a grill iteration) creates a duplicate. `mempalace_check_duplicate` catches this at 0.87 similarity threshold.

### Phase 2: Plan

Context sweep already ran. Focus on cross-room connections for architectural planning.

**Search for prior implementation context:**
```
mempalace_search query="<feature name> implementation" wing="<project>" limit=3
```

**For cross-project features — find tunnels:**
```
mempalace_list_tunnels wing="<project>" → any existing cross-project connections?
mempalace_traverse start_room="specs" max_hops=2 → connected ideas across rooms
```

**After producing the plan — store key decisions:**
```
mempalace_check_duplicate content="<ADR: decision, rationale, tradeoff>" threshold=0.87
mempalace_add_drawer wing="<project>" room="decisions" content="<ADR: decision, rationale, tradeoff>"
```

### Phase 3: Execute

**Before starting each REQ — search for relevant prior implementation:**
```
mempalace_search query="<REQ description>" wing="<project>" limit=2
```

**After completing each REQ — file implementation summary:**
```
mempalace_add_drawer wing="<project>" room="implementation" content="REQ-00X: <what was done, key files changed>"
```

Keep implementation summaries SHORT — 2-3 lines. These are for future context recovery, not detailed documentation.

### Phase 4: E2E

**After E2E tests complete — file results:**
```
mempalace_add_drawer wing="<project>" room="e2e" content="Phase 4 E2E: L0+L1 passed/failed, L2+L3 HITL status"
```

### Phase 5: Review

**After code review — file findings for future reference:**
```
mempalace_add_drawer wing="<project>" room="reviews" content="<review summary: critical issues, patterns to avoid>"
```

### Phase 6: Review + Simplify

**If simplification contradicts a prior decision — update it:**
```
# Find the decision (search is faster than list_drawers for this)
mempalace_search query="<decision keywords>" wing="<project>" room="decisions" limit=3

# If found and needs update, get full content first
mempalace_get_drawer drawer_id="<id from search>"

# Update with revised decision
mempalace_update_drawer drawer_id="<id>" content="<updated decision with rationale>"
```

### Phase 8: Commit + Knowledge Graph

**After successful commit — record in knowledge graph:**
```
mempalace_kg_add subject="<project>" predicate="shipped" object="<feature name>" valid_from="<today YYYY-MM-DD>"
```

**If fixing a bug — invalidate the prior bug fact:**
```
mempalace_kg_invalidate subject="<project>" predicate="has_bug" object="<bug description>" ended="<today>"
```

### Phase 9: Cleanup + Diary

**Write workflow summary to diary — use AAAK format for compression:**
```
mempalace_diary_write agent_name="doit" entry="SESSION:<date>:<feature>:<N> REQs,<N> files,commit:<short-hash>" topic="<feature>"
```

AAAK format compresses the entry — `SESSION:` prefix marks it as a session entry, `:` separates fields. This keeps diary entries readable while saving ~40% tokens on retrieval.

### Phase 10: Auto-Compact

**After compact — verify MemPalace auto-save and write final diary:**
```
mempalace_memories_filed_away → verify checkpoint saved
mempalace_diary_write agent_name="doit" entry="COMPACT:<date>:session ended, context compressed" topic="compact"
```

### Doc Capture Enhancement

**When capturing reference docs — file to MemPalace alongside `.doit/docs/`:**
```
# Check duplicate first — docs often get captured multiple times
mempalace_check_duplicate content="<doc content>" threshold=0.87

# If not duplicate:
mempalace_add_drawer wing="<project>" room="reference-docs" content="<doc content>" source_file="<original source>"
```

### Cross-Project Work

**When a feature spans multiple projects:**
```
# Create tunnel between related wings
mempalace_create_tunnel source_wing="project_a" source_room="api" target_wing="project_b" target_room="schema" label="API contract shared between projects"

# Explore existing cross-project connections
mempalace_list_tunnels wing="<project>"
mempalace_follow_tunnels wing="<project>" room="api"
mempalace_find_tunnels wing_a="project_a" wing_b="project_b"
```

### Maintenance (Periodic)

**When project is restructured or files moved — run during Phase -1 if >7 days since last sync:**
```
mempalace_sync project_dir="<project_root>" → dry-run report
mempalace_sync project_dir="<project_root>" apply=true → delete stale drawers
mempalace_reconnect → refresh index after deletions
```

### Debug Workflow (Type B)

**During D0 diagnosis — search for related prior bugs (already covered by Phase 0 Type B sweep):**
Phase 0's Type-specific search already found related bugs. If new information emerges during diagnosis:
```
mempalace_search query="<new bug keywords>" wing="<project>" room="bugs" limit=3
```

**After diagnosing — file the diagnosis:**
```
mempalace_add_drawer wing="<project>" room="bugs" content="Bug: <description>, root cause: <X>, fix: <Y>, date: <today>"
```

**After fix — invalidate the bug fact:**
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
