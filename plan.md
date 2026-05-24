# Phase 2: Plan

## Input

` .spec/current.md ` from Phase 1.

## Process

### Step 1: Code Graph Scan

Use **TokenSave** for code intelligence (discovery + call graph + code quality):
1. `tokensave_context` — get focused context for the feature/task (PRIMARY)
2. `tokensave_search` — find specific symbols by name from spec
3. `tokensave_impact` — analyze impact radius of specific symbols
4. `tokensave_files` — understand project file structure
5. `tokensave_coupling` — fan-in/fan-out analysis for module dependencies
6. `tokensave_health` — composite quality signal, identifies structural risks

- **Fallback:** If TokenSave not installed -> use `Agent Explore` for codebase exploration.

**TokenSave additional tools for deeper analysis:**
- `tokensave_callers` / `tokensave_callees` — who calls what, what does this call
- `tokensave_hotspots` — most connected symbols (highest call count)
- `tokensave_diff_context` — semantic context for changed files
- `tokensave_dsm` — design structure matrix, reveals hidden coupling

**Rule:** `tokensave_context` first, then narrow with `tokensave_search`/`tokensave_impact`.

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
