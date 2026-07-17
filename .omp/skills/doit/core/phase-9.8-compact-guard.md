# Phase 9.8 — Compact Guard (OMP Memory Sync)

**Trigger:** After Phase 9.5.5 (knowledge extraction), before Phase 10 (session summary + `[[MEMORY:compact]]`).

**Purpose:** Ensure all memory layers are persisted before OMP `compact` compresses the context window. Prevents data loss if `omp compact` fires mid-session or loses in-flight state.

## Why This Exists

OMP `compact` compresses the **LLM context window**, NOT MemPalace, lean-ctx, or filesystem. If `omp compact` fires:
- MemPalace: survives (own SQLite DB) ✅
- lean-ctx `ctx_session`: **at risk** if not flushed before compact ❌
- Knowledge extraction (Phase 9.5/9.5.5): at risk if user manually triggers compact before completion ❌

Without this guard, `omp compact` can silently drop in-flight decisions and session state.

## Guard Steps (MANDATORY — cannot skip)

Execute ALL steps in order. Each step MUST complete before the next.

### Step 1: Flush lean-ctx Session State

```
[[SHELL:run command="..."]] → ctx_session(action="save")
```

Save all in-flight task/finding/decision entries from the current session. Without this, compact may lose work-in-progress records.

**Verification:** `ctx_session(action="status")` → must return `{ last_saved: "<timestamp>" }` with a recent timestamp.

### Step 2: Flush MemPalace Diary

```
mempalace_diary_write agent_name="doit" entry="<session summary in AAAK format>"
```

Write a compressed diary entry covering: what was accomplished, key decisions, blockers. This is the cross-session recovery point if the next session starts fresh.

**Verification:** `mempalace_memories_filed_away` → `{ filed: true, message_count: N }`

### Step 3: Verify MemPalace KG is Populated

```
mempalace_kg_stats → check entity/triple count
```

If KG has 0 entities and Phase 8 (commit) ran, something went wrong. Log warning but continue — don't block Phase 10.

**If KG is empty:** `[WARN] MemPalace KG has 0 entities — Phase 8 may not have written facts. Phase 0 kg_query will return nothing next session.`

### Step 4: Verify Knowledge Extraction Completed

Check that Phase 9.5/9.5.5 extraction actually wrote to MemPalace:

```
mempalace_search wing="<project>" room="knowledge_distillation" max_distance=0.7
```

If empty or similarity < 0.3 → `[WARN] No knowledge extraction found. Phase 9.5.5 may have been skipped.` Continue to Phase 10 regardless.

### Step 5: Trigger Compact

ONLY after Steps 1-4 complete successfully:

```
[[MEMORY:compact]]
```

Resolve per adapter:
- **oh-my-pi:** `omp compact` (preferred) → `headroom_compress(...)` via MCP (fallback)
- **Other:** `headroom_compress(...)` via MCP

If compact fails → Phase 10 proceeds without it. All memory layers are already safe from Steps 1-3.
### Step 6: Write Cross-Session Continuation Hint

After Steps 1-5, write a next-session recovery file that Phase -1 can read to continue work:

```bash
cat > .doit/next-session-hint.md << 'EOF'
# Next Session Recovery Hint

## Last Session Summary
**Completed phases:** Phase 1-9.5.5
**Key decisions:** <summarize top 3 decisions>
**Open items:** <any in-progress items not yet completed>

## Quick Resume
If you want to continue this work, run:
```
/doit "Continue work on <project topic>"
```
Phase -1 will auto-detect the next-session-hint.md and recover the work state.

## Environment Snapshot
**Project type:** <type>
**Runtime:** <runtime>
**Key tools:** <codegraph, mempalace, lean-ctx>
**E2E status:** <automated or HITL>
EOF
```

This file is read by Phase -1 Step 11c.5 (lean-ctx session recovery) and Step 11c.6 (MemPalace diary context). It's a lightweight handoff mechanism between sessions.

**If .doit/ already has next-session-hint.md:** Append to it (don't overwrite). Mark with `## Session <timestamp>:` header to preserve history.

**Skip if:** User explicitly requested a "clean start" (no continuation hint).

## Compact Mode Detection (from Phase -1)

Phase -1 writes `COMPACT_MODE` to `[[CONFIG:main-instructions]]`:
- `COMPACT_MODE=omp` → use `omp compact` first, fall back to `headroom_compress`
- `COMPACT_MODE=none` → skip compact, use `headroom_compress` only
- Not set → use `headroom_compress` only (non-OMP)

## Anti-patterns

- **DO NOT** call `[[MEMORY:compact]]` before Step 5. Steps 1-4 are mandatory.
- **DO NOT** skip Step 1 thinking "lean-ctx auto-saves". It doesn't — explicit `action="save"` is required.
- **DO NOT** check MemPalace stats with `mempalace_get_taxonomy`. Use `mempalace_kg_stats` instead (cheaper).
- **DO** continue to Phase 10 even if a verification step warns — compact guard is about safety, not gating.

## Integration with Phase 10

Phase 10 runs AFTER Phase 9.8 completes. Phase 10 steps 1-4 (stats, KG, diary) are now redundant because Phase 9.8 just did them. Phase 10 should:
- Skip duplicate diary write (already done in Phase 9.8 Step 2)
- Still run all stats calls (RTK, headroom, lean-ctx) — these are read-only analytics
- The `[[MEMORY:compress]]` in Phase 10 is now a no-op because Phase 9.8 already triggered compact in Step 5