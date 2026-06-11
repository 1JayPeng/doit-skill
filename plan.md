# Phase 2: Plan

**[Think Before Coding]** Map impact at symbol and coupling level. Understand the code before touching it.

## Input

` .spec/current.md ` from Phase 1.

## Process

### Step 1: Code Graph Scan

Use **CodeGraph** for code intelligence (pre-built index, cross-language):
1. `codegraph_explore("how does X work")` — understand feature flow, survey code area (PRIMARY, returns symbols grouped by file)
2. `codegraph_search("symbolName")` — locate specific symbols by name
3. `codegraph_callers(node_id)` — who calls this symbol (upward call flow)
4. `codegraph_callees(node_id)` — what does this symbol call (downward call flow)
5. `codegraph_impact(node_id)` — assess edit blast radius before changes
6. `codegraph_node("symbolName")` — full source of a specific symbol (all overloads)

- **Fallback:** If CodeGraph not installed -> use **TokenSave** (`tokensave_context`, `tokensave_search`, `tokensave_impact`). If both unavailable -> `grep -rn` + `find` + `Read`.

**CodeGraph key principles:**
- **Trust the results** — don't re-verify with grep. The index is pre-built.
- **Treat returned source as already read** — no need to re-read files.
- **Check staleness banner** after edits — re-index if needed with `codegraph init -i`.

**[MP-READ] MemPalace — search for prior implementation context (Phase 0 sweep already ran):**
- `mempalace_search query="<feature name> implementation" wing="<project>" limit=3` — find prior implementation context
- `mempalace_traverse start_room="<project>/specs" max_hops=2` — find connected ideas across rooms

**[MP-WRITE] MemPalace — store architecture decisions (after plan is finalized):**
- `mempalace_check_duplicate content="<ADR: decision, rationale, tradeoff>" threshold=0.87`
- `mempalace_add_drawer wing="<project>" room="decisions" content="<ADR: decision, rationale, tradeoff>"`

**TokenSave (when available, deeper Rust-specific analysis):**
- `tokensave_type_hierarchy(node_id="<id>")` — full type hierarchy tree
- `tokensave_impls(trait="<name>")` — list all impl blocks for a trait
- `tokensave_derives(qualified_name="<type>")` — list #[derive(...)] macros
- `tokensave_inheritance_depth(limit=5)` — deepest class/interface hierarchies
- `tokensave_port_status(source_dir="<src>", target_dir="<tgt>")` — compare symbols between directories
- `tokensave_branch_diff(head="<head>", base="<base>")` — symbols changed between branches

**Rule:** `codegraph_explore` first, then narrow with `codegraph_search`/`codegraph_impact`.

#### Subagent Parallel Code Analysis (Optional, when 2+ independent modules)

When the feature affects multiple independent modules, parallelize the code graph analysis. See [subagent.md](subagent.md) for full patterns.

```
// Analyze multiple modules in parallel
Agent({
  description: "Analyze module A impact",
  prompt: "使用 tokensave_context 分析 '<feature>' 对模块 A 的影响。重点关注 API 变更、依赖关系、测试覆盖。",
  subagent_type: "Plan",
  run_in_background: true
})

Agent({
  description: "Analyze module B impact",
  prompt: "使用 tokensave_context 分析 '<feature>' 对模块 B 的影响。重点关注 API 变更、依赖关系、测试覆盖。",
  subagent_type: "Plan",
  run_in_background: true
})

// 主流程继续：准备实现计划框架
// 当后台 agent 完成后，汇总分析结果，生成实现计划
```

**When to use:** Feature touches 2+ independent modules (e.g., frontend + backend + database).
**When to skip:** Single-module feature, or modules have tight coupling.

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
