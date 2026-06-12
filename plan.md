# Phase 2: Plan

**[Think Before Coding]** Map impact at symbol and coupling level. Understand the code before touching it.

## Input

` .spec/current.md ` from Phase 1.

## Process

### Step 1: Code Graph Scan

**CodeGraph + TokenSave 互补并行** — 两个工具同等地位，各自优势互补：

**CodeGraph**（精准代码图查询，跨语言 AST）：
1. `codegraph_context(task="<feature description>")` — 理解功能流，获取相关符号 + 关系 + 代码
2. `codegraph_search("symbolName")` — 定位特定符号
3. `codegraph_callers(symbol)` — 谁调用此符号（向上调用流）
4. `codegraph_callees(symbol)` — 此符号调用什么（向下调用流）
5. `codegraph_impact(symbol)` — 评估编辑爆炸半径
6. `codegraph_node(symbol)` — 符号完整源码
7. `codegraph_explore(query)` — 一次检查多个相关符号的源码

**TokenSave**（即时改动检测 + 高级分析）：
8. `tokensave_context(task="<feature description>")` — 即时检测文件改动，15ms 索引
9. `tokensave_search("symbolName")` — 符号查找（改动后立即生效，无需 re-index）
10. `tokensave_impact(node_id)` — 影响分析（需先查 node_id）
11. `tokensave_diagnostics(scope="workspace")` — 运行类型检查器
12. `tokensave_dead_code()` — 查找潜在不可达代码
13. `tokensave_complexity()` — 按复杂度排名函数
14. `tokensave_test_map(node_id)` — 符号测试覆盖率
15. `tokensave_test_risk(path="...")` — 高风险未测试符号
16. `tokensave_unsafe_patterns(kinds=[...])` — 查找 panic/unsafe 站点
17. `tokensave_todos(kinds=["HACK", "TODO"])` — 查找 TODO/FIXME 标记
18. `tokensave_dsm(path="<src_dir>", format="clusters")` — 设计结构矩阵
19. `tokensave_coupling(direction="fan_in")` — 最被依赖的文件
20. `tokensave_hotspots()` — 最高连接度符号

**使用策略：**
- **规划阶段**：`codegraph_context` + `tokensave_context` 并行调用，交叉验证结果
- **符号查找**：`codegraph_search`（精准，不混入无关代码）
- **改动后验证**：`tokensave_search`（即时检测，无需等待 file watcher）
- **调用图**：`codegraph_callers/callees`（更准确）
- **质量分析**：`tokensave_diagnostics/dead_code/complexity/test_map`
- **代码编辑**：`tokensave_str_replace` / `tokensave_multi_str_replace` / `tokensave_insert_at`

**CodeGraph 优势：** 查询精准度高，callers/callees 准确，跨语言支持完整（Python/TS/Rust/Java/Go），符号名直接查询
**TokenSave 优势：** 改动跟随即时检测（15ms 索引），高级静态分析（10+ 种质量工具），代码编辑原语

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

**TokenSave 高级分析工具（按需使用）：**
- `tokensave_diagnostics(scope="workspace")` — run type checker
- `tokensave_dead_code()` — find potentially unreachable code
- `tokensave_complexity()` — functions ranked by complexity
- `tokensave_test_map(node_id)` — test coverage per symbol
- `tokensave_test_risk(path="...")` — high-risk untested symbols
- `tokensave_unsafe_patterns(kinds=[...])` — find panic/unsafe sites
- `tokensave_todos(kinds=["HACK", "TODO"])` — find TODO/FIXME markers
- `tokensave_type_hierarchy(node_id="<id>")` — full type hierarchy tree
- `tokensave_impls(trait="<name>")` — list all impl blocks for a trait
- `tokensave_derives(qualified_name="<type>")` — list #[derive(...)] macros
- `tokensave_dsm(path="<src_dir>", format="clusters")` — design structure matrix
- `tokensave_coupling(direction="fan_in")` — most depended-on files
- `tokensave_hotspots()` — highest connectivity symbols
- `tokensave_signature_search(returns="Result<", params=["&mut self"])` — search by signature shape
- `tokensave_str_replace` / `tokensave_multi_str_replace` / `tokensave_insert_at` — code editing

**Rule:** `codegraph_context` first, then narrow with `codegraph_search`/`codegraph_impact`. Use TokenSave for advanced static analysis (diagnostics, dead code, complexity, test coverage).

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
