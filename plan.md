# Phase 2: Plan

**[Think Before Coding]** Map impact at symbol and coupling level. Understand the code before touching it.

## Input

` .spec/current.md ` from Phase 1.

## Process

### Step 1: Code Graph Scan

Use **TokenSave** for code intelligence (discovery + call graph + code quality):
1. `tokensave_context` — get focused context for the feature/task (PRIMARY)
2. `tokensave_search` — find specific symbols by name from spec
3. `tokensave_similar(symbol="<name>")` — find symbols with similar names (avoid naming inconsistency)
4. `tokensave_impact` — analyze impact radius of specific symbols
5. `tokensave_files` — understand project file structure
6. `tokensave_coupling` — fan-in/fan-out analysis for module dependencies
7. `tokensave_health` — composite quality signal, identifies structural risks
8. `tokensave_status` — aggregate statistics (node/edge/file counts, DB size)
9. `tokensave_config(key="dependencies", path="Cargo.toml")` — read project config without file reads (TOML/JSON)
10. `tokensave_outline(file="<key_file>")` — flat list of top-level symbols (quick file overview)
11. `tokensave_module_api(path="<src_dir>")` — public API surface (what's exposed to consumers)

- **Fallback:** If TokenSave not installed -> use **CodeGraph** (`codegraph_explore`, `codegraph_search`, `codegraph_callers/callees`, `codegraph_impact`, `codegraph_node`). If CodeGraph also unavailable -> `grep -rn` + `find` + `Read`.

**TokenSave additional tools for deeper analysis:**
- `tokensave_callers` / `tokensave_callees` — who calls what, what does this call
- `tokensave_hotspots` — most connected symbols (highest call count)
- `tokensave_diff_context` — semantic context for changed files
- `tokensave_dsm` — design structure matrix, reveals hidden coupling
- `tokensave_body(symbol="<name>")` — return full source body of a symbol (faster than node lookup)
- `tokensave_signature(qualified_name="<name>")` — get function signature without body
- `tokensave_signature_search(params="&mut self", returns="Result")` — find functions by signature shape

**[MP-READ] MemPalace — search for prior implementation context (Phase 0 sweep already ran):**
- `mempalace_search query="<feature name> implementation" wing="<project>" limit=3` — find prior implementation context
- `mempalace_traverse start_room="<project>/specs" max_hops=2` — find connected ideas across rooms

**[MP-WRITE] MemPalace — store architecture decisions (after plan is finalized):**
- `mempalace_check_duplicate content="<ADR: decision, rationale, tradeoff>" threshold=0.87`
- `mempalace_add_drawer wing="<project>" room="decisions" content="<ADR: decision, rationale, tradeoff>"`

**Type system analysis (when task involves interfaces, traits, classes):**
- `tokensave_type_hierarchy(node_id="<id>")` — full type hierarchy tree for traits/interfaces/classes
- `tokensave_rank(edge_kind="implements", direction="incoming")` — most implemented interface (high coupling)
- `tokensave_distribution(path="<dir>")` — node kind breakdown per file/directory
- `tokensave_largest(node_kind="class", limit=5)` — largest classes (potential god classes)
- `tokensave_impls(trait="<name>")` — list all impl blocks for a trait (find all implementors)
- `tokensave_derives(qualified_name="<type>")` — list #[derive(...)] macros (synthesized methods)
- `tokensave_inheritance_depth(limit=5)` — deepest class/interface hierarchies

**Porting tasks (when porting code between languages/modules):**
- `tokensave_port_status(source_dir="<src>", target_dir="<tgt>")` — compare symbols, track progress
- `tokensave_port_order(source_dir="<src>")` — topological sort, port leaves first then dependents

**Multi-branch (when comparing branches):**
- `tokensave_branch_list()` — list tracked branches with DB sizes
- `tokensave_branch_search(branch="<name>", query="<symbol>")` — search symbols in another branch
- `tokensave_branch_diff(head="<head>", base="<base>")` — symbols added/removed/changed between branches

**Rule:** `tokensave_context` first, then narrow with `tokensave_search`/`tokensave_impact`.

Tool selection guidance lives in global CLAUDE.md.

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
