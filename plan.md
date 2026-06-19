# Phase 2: Plan

**[Think Before Coding]** Map impact at symbol and coupling level. Understand the code before touching it.

## Input

` .spec/current.md ` from Phase 1.

## Process

### Step 0.5: Architecture Orientation (before code graph scan)

**lean-ctx architecture tools** — fast, compressed overview before deep code graph scan:
```
[CALL] ctx_architecture(action="overview") — architecture overview, clusters, layers
[CALL] ctx_repomap(max_tokens=2048) — PageRank importance map of symbols
```
**Web projects:** additionally `[CALL] ctx_routes` — extract HTTP routes from Express, Flask, FastAPI, Actix, Spring, Rails, Next.js.

**Why:** `ctx_architecture` gives cluster/layer/cycle analysis in ~1K tokens, replacing 3-5 manual file reads. `ctx_repomap` shows which symbols are most important by PageRank — focuses the code graph scan.

### Step 1: Code Graph Scan

**CodeGraph**（精准代码图查询，跨语言 AST）：
1. `codegraph_context(task="<feature description>")` — 理解功能流，获取相关符号 + 关系 + 代码
2. `codegraph_search("symbolName")` — 定位特定符号
3. `codegraph_callers(symbol)` — 谁调用此符号（向上调用流）
4. `codegraph_callees(symbol)` — 此符号调用什么（向下调用流）
5. `codegraph_impact(symbol)` — 评估编辑爆炸半径
6. `codegraph_node(symbol)` — 符号完整源码
7. `codegraph_explore(query)` — 一次检查多个相关符号的源码

**lean-ctx batch read** — after identifying relevant files, batch read signatures:
```
[CALL] ctx_multi_read(paths=[<relevant_files>], mode="signatures") — batch read API surface
```
**Why:** one `ctx_multi_read` call replaces N individual `ctx_read` calls, saving ~3000 tokens for 5-10 files.

**CodeGraph 使用原则：**
- **Trust the results** — don't re-verify with grep. The index is pre-built.
- **Treat returned source as already read** — no need to re-read files.
- **Auto-sync** — file watcher debounces ~500ms; don't re-query immediately after edits.
- **Answer directly** — `codegraph_context` first, then ONE `codegraph_explore` for source. No grep+read loops.

**[MP-READ] MemPalace — search for prior implementation context (Phase 0 sweep already ran):**
- `mempalace_search query="<feature name> implementation" wing="<project>" limit=3` — find prior implementation context
- `mempalace_traverse start_room="<project>/specs" max_hops=2` — find connected ideas across rooms

**[MP-WRITE] MemPalace — store architecture decisions (after plan is finalized):**
- `mempalace_check_duplicate content="<ADR: decision, rationale, tradeoff>" threshold=0.87`
- `mempalace_add_drawer wing="<project>" room="decisions" content="<ADR: decision, rationale, tradeoff>"`

**Rule:** `codegraph_context` first, then narrow with `codegraph_search`/`codegraph_impact`.

#### Subagent Parallel Code Analysis (Optional, when 2+ independent modules)

When the feature affects multiple independent modules, parallelize the code graph analysis. See [subagent.md](subagent.md) for full patterns.

```
// Analyze multiple modules in parallel
Agent({
  description: "Analyze module A impact",
  prompt: "使用 codegraph_context 分析 '<feature>' 对模块 A 的影响。重点关注 API 变更、依赖关系、测试覆盖。",
  subagent_type: "Plan",
  run_in_background: true
})

Agent({
  description: "Analyze module B impact",
  prompt: "使用 codegraph_context 分析 '<feature>' 对模块 B 的影响。重点关注 API 变更、依赖关系、测试覆盖。",
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
