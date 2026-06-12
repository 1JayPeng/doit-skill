# Phase 2: Plan

**[Think Before Coding]** Map impact at symbol and coupling level. Understand the code before touching it.

## Input

` .spec/current.md ` from Phase 1.

## Process

### Step 1: Code Graph Scan

Use **TokenSave** for code intelligence (primary code graph tool):
1. `tokensave_context(task="<feature description>")` — understand feature flow, get relevant symbols + relationships + code (PRIMARY)
2. `tokensave_search("symbolName")` — locate specific symbols by name
3. `tokensave_callers(node_id)` — who calls this symbol (upward call flow)
4. `tokensave_callees(node_id)` — what does this symbol call (downward call flow)
5. `tokensave_impact(node_id)` — assess edit blast radius before changes
6. `tokensave_node(node_id)` — full source of a specific symbol

- **Fallback:** If TokenSave not installed -> use **CodeGraph** (`codegraph_context`, `codegraph_search`, `codegraph_impact`). If both unavailable -> `grep -rn` + `find` + `Read`.

**TokenSave key principles:**
- **Trust the results** — don't re-verify with grep. The index is pre-built.
- **Treat returned source as already read** — no need to re-read files.
- **Auto-sync** — file watcher debounces ~500ms; don't re-query immediately after edits.

**[MP-READ] MemPalace — search for prior implementation context (Phase 0 sweep already ran):**
- `mempalace_search query="<feature name> implementation" wing="<project>" limit=3` — find prior implementation context
- `mempalace_traverse start_room="<project>/specs" max_hops=2` — find connected ideas across rooms

**[MP-WRITE] MemPalace — store architecture decisions (after plan is finalized):**
- `mempalace_check_duplicate content="<ADR: decision, rationale, tradeoff>" threshold=0.87`
- `mempalace_add_drawer wing="<project>" room="decisions" content="<ADR: decision, rationale, tradeoff>"`

**TokenSave 高级分析工具（按需使用）：**
- `tokensave_type_hierarchy(node_id="<id>")` — full type hierarchy tree
- `tokensave_impls(trait="<name>")` — list all impl blocks for a trait
- `tokensave_derives(qualified_name="<type>")` — list #[derive(...)] macros
- `tokensave_inheritance_depth(limit=5)` — deepest class/interface hierarchies
- `tokensave_dsm(path="<src_dir>", format="clusters")` — design structure matrix
- `tokensave_coupling(direction="fan_in")` — most depended-on files
- `tokensave_hotspots()` — highest connectivity symbols
- `tokensave_dead_code()` — potentially unreachable code
- `tokensave_complexity()` — functions ranked by complexity
- `tokensave_signature_search(returns="Result<", params=["&mut self"])` — search by signature shape

**Rule:** `tokensave_context` first, then narrow with `tokensave_search`/`tokensave_impact`.

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
