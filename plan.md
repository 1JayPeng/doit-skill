# Phase 2: Plan

## Input

` .spec/current.md ` from Phase 1.

## Process

### Step 1: Code Graph Scan

Use **CodeGraph** for symbol-level exploration (fast, AST-accurate):
1. `codegraph_context` — get focused context for the feature/task (PRIMARY)
2. `codegraph_search` — find specific symbols by name from spec
3. `codegraph_impact` — analyze impact radius of specific symbols
4. `codegraph_files` — understand project file structure

- **Fallback:** If CodeGraph not installed -> use `Agent Explore` for codebase exploration. Same structural search, slightly slower.

Use **Code-Review-Graph** for community/architecture analysis:
1. `list_graph_stats` — verify graph built
2. `list_communities` — see which communities to touch
3. `get_impact_radius` — understand blast radius of affected modules

- **Fallback:** If Code-Review-Graph not installed -> skip community analysis. Rely on CodeGraph alone for impact assessment. Announce `[WARN] code-review-graph unavailable, skipping community-level analysis`.

Use **Context-Mode** for codebase exploration:
1. `ctx_batch_execute` — run multiple commands, auto-index output, search with queries (one call replaces many)
2. `ctx_execute_file` — process large files without loading into context (files >20 lines)
3. `ctx_fetch_and_index` — fetch and index external documentation/URLs for research

- **Fallback:** If Context-Mode not installed ->
  - `ctx_batch_execute` -> `Agent Explore` + native `grep`/`find`
  - `ctx_execute_file` -> `Read` tool (loads file into context, uses more tokens)
  - `ctx_fetch_and_index` -> `WebFetch` (no indexing, no follow-up search)

**Rule:** `ctx_execute_file` for analysis, `Read` for files you'll Edit. Keep raw data in sandbox.

Tool selection guidance lives in global CLAUDE.md.

### Step 2: Implementation Order

Sort REQs by dependency:
1. No-dependency REQs first (foundation)
2. Dependent REQs in topological order
3. Group by file/module — minimize context switch

### Step 3: Branch Check

If `.spec/current.md` exists from a prior session, resume. Append new REQs if scope changed.

### Step 4: Present Plan

Show user:
```
REQ-001 [TODO] -> file_a.py, file_b.py (new module, no deps)
REQ-002 [TODO] -> file_c.py (depends on REQ-001)
```

User confirms -> execute.
