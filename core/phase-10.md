# Phase 10 — Session Summary

**[CALL] Execute ALL:**

1. RTK token report: `ctx_shell("rtk gain")`
2. lean-ctx stats: `ctx_stats()`
3. Context-Mode stats: `ctx stats`
4. Headroom stats: `headroom_stats` (MCP)
5. MemPalace KG + diary: `mempalace_diary_write`, `mempalace_kg_stats`
6. Session decision: `ctx_session(action="decision", ...)`
7. Caveman compress CLAUDE.md

**Phase 10 hard gate — `[[MEMORY:compact]]` (OMP) or `[[MEMORY:compress]]` (fallback) is last step, cannot skip.**

**OMP native path (preferred):**
```
[SHELL:run command="omp compact"]
```

**Fallback path (non-OMP or OMP compact unavailable):**
```
[CALL] headroom_compress(content="...")
```

When `COMPACT_MODE=omp` detected in Phase -1 → use `omp compact`. Otherwise → `headroom_compress`.
