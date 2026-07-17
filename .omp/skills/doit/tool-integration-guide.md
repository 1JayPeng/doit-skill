# doit 外部工具集成指南

**人类可读版** — 9 个外部工具在 doit 工作流中具体做什么、什么时候用、怎么配合。

---

## 一、四层记忆架构

doit 工作流依赖四个互补的持久化层：

| 层级 | 管什么 | 生命周期 | 类比 |
|------|--------|----------|------|
| **CodeGraph** | 代码图（符号、调用关系、影响分析） | 随代码变更实时更新 | "项目的实时地图" |
| **Context-Mode** | 当前会话的命令输出、索引、搜索 | 会话结束即消失 | "本次对话的笔记本" |
| **MemPalace** | 跨会话的语义记忆 + 知识图谱 | 永久存储，跨会话存活 | "项目的长期记忆库" |
| **Headroom** | 上下文优化（代理压缩、记忆持久化） | 跨会话存活 | "token 节省器" |

**核心原则：任何一层不可用时，工作流不阻塞，自动降级到剩余层。**

---

## 二、后台长任务机制（Tmux + Monitor）

doit 内置三种后台任务机制，按任务时长自动选择：

| 层级 | 适用场景 | 机制 | 自动继续 |
|------|---------|------|---------|
| **Foreground** | <10s | 直接 Bash 执行 | 不需要 |
| **Background** | 10s-5min | Shell `&` + 日志文件 + `[START]`/`[END]` 标记 | 不需要 |
| **Tmux + Monitor** | >5min | 命名 tmux 会话 + Claude Code Monitor + 自动继续 | **是** |

**Tmux + Monitor 工作流程：**
1. 长任务在命名 tmux 会话中运行（如 `doit-build`）
2. Claude Code 设置 Monitor，定期检查日志文件中的 `[END]` 标记
3. Monitor 触发 → Claude Code 读取日志 → 检查退出码 → **自动进入下一阶段**
4. 全程无需人工干预

详见 [background-process.md](background-process.md)。

## 三、外部工具总览

| # | 工具 | 类型 | 安装方式 | 核心作用 |
|---|------|------|----------|----------|
| 1 | **CodeGraph** | MCP 服务器 | `npm i -g @colbymchenry/codegraph` | **精准代码图查询**：AST 解析、符号查找、调用关系、影响分析 |
| 3 | **MemPalace** | Claude Plugin | `claude plugin install --scope user mempalace` | 跨会话语义记忆：spec/决策/实现笔记的长期存储 |
| 4 | **Context-Mode** | Claude Plugin | `claude plugin marketplace add mksglu/context-mode` | 上下文管理：命令输出自动索引 + 语义搜索 |
| 5 | **RTK** | 全局 CLI | `curl ... \| sh` | Token 优化代理：所有 shell 命令节省 60-90% token |
| 6 | **uv** | 全局 CLI | `pip install uv` | Python 虚拟环境管理：创建 venv + 运行命令 |
| 7 | **caveman** | Skill | `curl ... \| bash` | 压缩通信模式：减少 75% token，砍掉废话保留技术内容 |
| 8 | **code-review** | Claude Plugin | `claude plugin install code-review` | 代码审查：Phase 5 自动审查 diff |
| 9 | **Tavily MCP** | 远程 MCP | 只需 API key，无需安装 | 互联网搜索：Phase 1 spec 生成前的头脑风暴 |

---

## 四、按阶段详解

### Phase -1：环境检测

**目的：** 检测项目运行时、虚拟环境、包管理器。检测所有外部工具可用性。

| 工具 | 具体调用 | 目的 |
|------|---------|------|
| **CodeGraph** | `codegraph --version` | 检测是否安装 |
| **MemPalace** | `mempalace_status` | 检测是否安装 |
| **MemPalace** | `mempalace_hook_settings silent_save=true desktop_toast=false` | 配置自动保存钩子 |
| **MemPalace** | `mempalace_reconnect` | 刷新内存 HNSW 索引 |
| **MemPalace** | `mempalace_get_taxonomy` | 获取 wing→room→drawer 完整树 |
| **MemPalace** | `mempalace_kg_stats` | 知识图谱统计 |
| **MemPalace** | `mempalace_graph_stats` | 宫殿图统计 |
| **MemPalace** | `mempalace_list_wings` | 列出所有项目翼 |
| **MemPalace** | `mempalace_sync project_dir="<root>"` | 清理过期抽屉（dry-run） |

**降级：** 任何工具不可用 → 静默跳过，不阻塞工作流。

---

### Phase 0：分类请求

**目的：** 分类用户需求为 R(恢复)/S(简单)/F(功能)/B(修复)。

| 工具 | 具体调用 | 目的 |
|------|---------|------|
| **caveman** | `Skill skill="caveman"` | 启用压缩通信模式，整个会话生效 |
| **MemPalace** | `mempalace_diary_read agent_name="doit" last_n=3` | 恢复型请求：读最近日记 |
| **MemPalace** | `mempalace_search query="<project>" wing="<project>" limit=5` | 恢复型请求：搜索项目上下文 |
| **MemPalace** | `mempalace_kg_query entity="<project>"` | 恢复型请求：查询知识图谱 |
| **MemPalace** | `mempalace_kg_timeline entity="<project>"` | 恢复型请求：项目时间线 |

---

### Phase 1：Spec 生成

**目的：** 互联网搜索 → grill 用户想法 → 生成 spec → 存储。

| 工具 | 具体调用 | 目的 |
|------|---------|------|
| **Tavily MCP** | Tavily MCP 搜索 | 互联网搜索现有方案、常见坑、替代方法 |
| **MemPalace** | `mempalace_list_rooms wing="<project>"` | 列出房间，了解记忆结构 |
| **MemPalace** | `mempalace_search query="<keywords>" wing="<project>" limit=3` | 搜索历史决策，避免重复 |
| **MemPalace** | `mempalace_add_drawer wing="<project>" room="specs" content="<spec>"` | 存储 spec |
| **MemPalace** | `mempalace_update_drawer drawer_id="<id>" content="<updated>"` | 更新 spec（范围变化时） |

**降级：** Tavily 不可用 → Claude Code 内置 `WebSearch`。

---

### Phase 2：计划

**目的：** 代码图扫描 → 影响分析 → 实现顺序。

| 工具 | 具体调用 | 目的 |
|------|---------|------|
| **CodeGraph** | `codegraph_search("symbolName")` | 按名称定位符号 |
| **CodeGraph** | `codegraph_callers(symbol)` | 谁调用了此符号（向上调用链） |
| **CodeGraph** | `codegraph_callees(symbol)` | 此符号调用了谁（向下调用链） |
| **CodeGraph** | `codegraph_impact(symbol)` | 评估编辑影响面 |
| **CodeGraph** | `codegraph_node(symbol)` | 获取符号完整源码 |
| **CodeGraph** | `codegraph_explore(query)` | 多个相关符号的源码一次性查看 |
| **MemPalace** | `mempalace_search query="<feature> implementation"` | 搜索历史实现 |
| **MemPalace** | `mempalace_traverse start_room="<project>/specs" max_hops=2` | 跨房间探索 |
| **MemPalace** | `mempalace_add_drawer wing="<project>" room="decisions"` | 存储决策 |


---

### Phase 3：执行（TDD 循环）

**目的：** 每个 REQ 的 RED→GREEN→REFACTOR→REVIEW+SIMPLIFY 循环。长构建任务（>5min）使用 Tmux + Monitor 实现自动继续。

| 工具 | 具体调用 | 目的 |
|------|---------|------|
| **CodeGraph** | `codegraph_search("symbolName")` | 按名称定位符号 |
| **CodeGraph** | `codegraph_callers(symbol)` | 谁调用了这个符号 |
| **CodeGraph** | `codegraph_callees(symbol)` | 这个符号调用了谁 |
| **CodeGraph** | `codegraph_impact(symbol)` | 评估改动影响面 |
| **CodeGraph** | `codegraph_node(symbol)` | 获取符号完整源码 |
| **Context-Mode** | `ctx_search(queries=[...])` | 搜索之前索引的内容 |
| **MemPalace** | `mempalace_search query="<REQ>" wing="<project>" limit=2` | 恢复上下文 |
| **MemPalace** | `mempalace_get_drawer drawer_id="<id>"` | 获取抽屉完整内容 |
| **MemPalace** | `mempalace_list_drawers wing="<project>" room="implementation" limit=5` | 浏览最近实现笔记 |

**IMPLEMENT 步骤（修改代码）：**

| 工具 | 具体调用 | 目的 |
|------|---------|------|

**长任务执行（Tmux + Monitor）：**

| 工具 | 具体调用 | 目的 |
|------|---------|------|
| **Tmux** | `tmux new-session -d -s "doit-build"` | 创建命名会话 |
| **Tmux** | `tmux send-keys -t "doit-build" '...' Enter` | 发送长命令到 tmux |
| **Monitor** | `Monitor "Watch build" "grep -q '\[END\]' .scratch/logs/build.log" --interval 30` | 监控完成标记 |
| **Bash** | `tail -1 .scratch/logs/build.log` | Monitor 触发后读取退出码 |

当 Monitor 触发时，Claude Code 自动读取日志、检查退出码、继续下一阶段。详见 [background-process.md](background-process.md)。

**REVIEW+SIMPLIFY 步骤：**

| 工具 | 具体调用 | 目的 |
|------|---------|------|
| **RTK** | `rtk gain` | 报告 token 节省 |

**Test Execution 步骤：**

| 工具 | 具体调用 | 目的 |
|------|---------|------|
| **Context-Mode** | `ctx_execute` | 运行测试命令，输出自动索引 |
| **Context-Mode** | `ctx_batch_execute` | 并行运行多个测试命令 |
| **RTK** | 自动包装所有 shell 命令 | 节省 60-90% token |
| **uv** | `uv venv` + `uv run` | Python 虚拟环境 |

**State Tracking 步骤：**

| 工具 | 具体调用 | 目的 |
|------|---------|------|
| **MemPalace** | `mempalace_add_drawer wing="<project>" room="implementation"` | 存储实现摘要 |

---

### Phase 4：E2E 测试

**目的：** 端到端测试，真实环境验证。E2E 测试通常耗时较长（服务器启动 + 测试套件），适合 Tmux + Monitor。

| 工具 | 具体调用 | 目的 |
|------|---------|------|
| **CodeGraph** | `codegraph_search("symbolName")` | 找入口函数 |
| **CodeGraph** | `codegraph_node(symbol)` | 获取函数签名 |
| **Context-Mode** | `ctx_batch_execute` | 并行运行多个命令 |
| **Context-Mode** | `ctx_search(queries=[<REQs>])` | 查找 spec REQ |
| **Context-Mode** | `ctx_execute` | 运行测试命令 |
| **MemPalace** | `mempalace_add_drawer wing="<project>" room="e2e"` | 存储 E2E 结果 |
| **Tmux** | `tmux new-session -d -s "doit-e2e"` | E2E 服务器 + 测试在 tmux 中运行 |
| **Monitor** | `Monitor "Watch E2E" "grep -q '\[END\]' .scratch/logs/e2e-full.log" --interval 30` | 监控 E2E 完成 |

---

### Phase 5：审查

**目的：** 代码审查 + 架构检查 + 安全扫描。

| 工具 | 具体调用 | 目的 |
|------|---------|------|
| **code-review** | `Skill skill="code-review"` | 审查 diff |
| **Context-Mode** | `ctx_search(queries=[<REQs>])` | 查找 spec REQ |
| **MemPalace** | `mempalace_add_drawer wing="<project>" room="reviews"` | 存储审查结果 |
| **MemPalace** | `mempalace_kg_add subject="<project>" predicate="passed_review"` | 记录通过审查 |
| **RTK** | `rtk discover` | 发现优化机会 |
| **RTK** | `rtk gain --history` | 命令历史 |

---

### Phase 6：简化

**目的：** 读代码 → 简化 → 文档检查 → 最终验证。

| 工具 | 具体调用 | 目的 |
|------|---------|------|
| **Context-Mode** | `ctx_execute` | 运行测试 |
| **Context-Mode** | `ctx_search(queries=[...])` | 搜索之前索引的内容 |
| **MemPalace** | `mempalace_list_drawers wing="<project>" room="decisions"` | 浏览决策 |
| **MemPalace** | `mempalace_get_drawer drawer_id="<id>"` | 获取决策完整内容 |
| **MemPalace** | `mempalace_update_drawer drawer_id="<id>" content="<updated>"` | 更新决策 |

---

### Phase 7：E2E 验证循环

**目的：** 简化后重新运行 E2E 测试，确保输出匹配 spec。E2E 验证循环通常耗时较长，适合 Tmux + Monitor。

| 工具 | 具体调用 | 目的 |
|------|---------|------|
| **Context-Mode** | `ctx_execute` | 运行测试命令 |
| **Context-Mode** | `ctx_search(queries=[<REQs>])` | 查找 spec REQ |
| **Tmux** | `tmux new-session -d -s "doit-e2e-verify"` | E2E 验证在 tmux 中运行 |
| **Monitor** | `Monitor "Watch E2E verify" "grep -q '\[END\]' .scratch/logs/e2e-verify.log" --interval 30` | 监控验证完成 |

---

### Phase 8：提交 + 推送

**目的：** 生成提交信息 → commit → push → 存储到 MemPalace。

| 工具 | 具体调用 | 目的 |
|------|---------|------|
| **Context-Mode** | `ctx_batch_execute` | 并行运行 git 命令 |
| **MemPalace** | `mempalace_kg_add subject="<project>" predicate="shipped"` | 记录上线功能 |
| **MemPalace** | `mempalace_kg_invalidate subject="<project>" predicate="has_bug"` | 标记 bug 已修复 |
| **MemPalace** | `mempalace_diary_write agent_name="doit"` | 写日记 |

---

### Phase 9：清理

**目的：** 删除中间文件。

| 工具 | 具体调用 | 目的 |
|------|---------|------|
| **MemPalace** | `mempalace_diary_write agent_name="doit"` | 写日记 |

---

### Phase 10：Session Summary

**目的：** 收集 session 统计信息，保存知识。

| 工具 | 具体调用 | 目的 |
|------|---------|------|
| **RTK** | `rtk gain` | 报告 session token 节省 |
| **RTK** | `rtk gain --history` | 每命令节省历史 |
| **Context-Mode** | `ctx stats` | 记录 token 节省 |
| **MemPalace** | `mempalace_diary_write agent_name="doit"` | 写日记 |
| **MemPalace** | `mempalace_memories_filed_away` | 验证自动保存 |
| **MemPalace** | `mempalace_kg_timeline entity="<project>"` | 项目时间线 |

---

## 五、工具协作时序图

```
Phase -1  环境检测
  ├─ CodeGraph: status 检测
  ├─ MemPalace: status + hook_settings + reconnect + taxonomy + kg_stats + graph_stats + list_wings + sync
  └─ caveman: 启用压缩模式

Phase 0   分类请求
  ├─ caveman: 压缩通信模式
  ├─ MemPalace: diary_read + search + kg_query + kg_timeline (恢复型请求)
  └─ RTK: 自动包装所有 shell 命令

Phase 1   Spec 生成
  ├─ Tavily MCP: 互联网搜索
  ├─ MemPalace: list_rooms + search + add_drawer + update_drawer
  └─ RTK: 自动包装所有 shell 命令

Phase 2   计划
  ├─ CodeGraph: context + search + callers + callees + impact + node + explore
  ├─ MemPalace: search + traverse + add_drawer
  ├─ Context-Mode: ctx_batch_execute
  └─ RTK: 自动包装所有 shell 命令

Phase 3   执行（每个 REQ 循环）
  ├─ CodeGraph: context + search + callers + callees + impact + node
  ├─ MemPalace: search + get_drawer + list_drawers + add_drawer
  ├─ Context-Mode: ctx_search + ctx_execute + ctx_batch_execute
  ├─ RTK: 自动包装所有 shell 命令 + gain 报告
  └─ uv: Python 虚拟环境

Phase 4   E2E 测试
  ├─ CodeGraph: search + node
  ├─ Context-Mode: ctx_batch_execute + ctx_search + ctx_execute
  ├─ MemPalace: add_drawer (e2e 结果)
  └─ RTK: 自动包装所有 shell 命令

Phase 5   审查
  ├─ code-review: 审查 diff
  ├─ CodeGraph: context + search + impact
  ├─ MemPalace: add_drawer (reviews) + kg_add (passed_review)
  ├─ Context-Mode: ctx_search
  ├─ RTK: discover + gain --history
  └─ RTK: 自动包装所有 shell 命令

Phase 6   简化
  ├─ MemPalace: list_drawers + get_drawer + update_drawer
  ├─ Context-Mode: ctx_execute + ctx_search
  └─ RTK: 自动包装所有 shell 命令

Phase 7   E2E 验证循环
  ├─ Context-Mode: ctx_execute + ctx_search
  └─ RTK: 自动包装所有 shell 命令

Phase 8   提交 + 推送
  ├─ Context-Mode: ctx_batch_execute
  ├─ MemPalace: kg_add + kg_invalidate + diary_write
  └─ RTK: 自动包装所有 shell 命令

Phase 9   清理
  ├─ MemPalace: diary_write
  └─ RTK: 自动包装所有 shell 命令

Phase 10  Session Summary
  ├─ RTK: gain + gain --history
  ├─ Context-Mode: ctx stats
  └─ MemPalace: diary_write + memories_filed_away + kg_timeline
```

---

## 六、关键设计决策


- **CodeGraph** 是代码的"实时地图"——AST 解析，跨语言符号查找/调用关系/影响分析，回答"这个函数在哪、谁调用了它、改它会破坏什么"
- **MemPalace** 是项目的"长期记忆"——回答"上次我们为什么选 JWT"、"REQ-001 改了什么文件"



- **CodeGraph** 精准代码图查询 — 跨语言 AST 符号查找，调用图精准，影响分析准确，symbol-name 查询无需 node_id

### 2. 为什么 MemPalace 不替代文件系统？

MemPalace 是**补充**，不是替代：
- `.spec/current.md` 仍然是 spec 的权威来源（CodeGraph 可索引、git 可追踪）
- `.doit/docs/` 仍然是文档的权威来源（git 可追踪变更历史）
- MemPalace 额外提供**语义搜索**（"找之前关于认证的讨论"）和**跨会话恢复**（"上次做到哪了"）

### 3. 为什么降级策略是静默跳过？

工作流不应该因为一个记忆层不可用就卡住。降级顺序：
3. 两者都不可用 → 用 grep/find/Read
4. MemPalace 不可用 → 用文件系统（.doit/docs/, .spec/archive/）
5. Context-Mode 不可用 → 用原生 Bash（不索引）

### 4. MemPalace 的 Wing/Room 约定

| 房间 | 存什么 | 哪个阶段写入 |
|------|--------|-------------|
| `specs` | Phase 1 生成的 spec | Phase 1 |
| `decisions` | 架构决策（ADR） | Phase 2 |
| `implementation` | 每个 REQ 的实现摘要 | Phase 3 |
| `e2e` | E2E 测试结果 | Phase 4 |
| `reviews` | 代码审查发现 | Phase 5 |
| `reference-docs` | 用户提供的参考文档 | Doc Capture |
| `bugs` | Bug 诊断结果 | Debug D0 |

Wing 名 = 项目根目录名（如 `my-api`, `doit-skill`）。

### 5. RTK 为什么只在 Phase 3 和 Phase 10 显式调用？

RTK 通过 PreToolUse hook **自动包装所有 shell 命令**，不需要在每个阶段手动调用。Phase 3 和 Phase 10 只是显式报告节省情况。

### 6. 为什么 caveman 只在 Phase 0 启用？

caveman 是**整个会话**的压缩通信模式，Phase 0 启用后一直生效，不需要在每个阶段重新启用。

---

## 七、降级策略总览

| 工具 | 不可用时的降级 | 影响阶段 |
|------|--------------|---------|
| 两者都不可用 | `grep` + `find` + `Read` | 2, 3, 4, 5, 6, 7, 8 |
| Context-Mode | 原生 Bash（不索引） | 2, 3, 4, 7, 8 |
| Tavily MCP | `WebSearch`（内置） | 1 |
| RTK | Bash（不优化） | 所有阶段 |
| uv | `pip` + `python3 -m venv` | 3, 4, 7 |
| caveman | 正常 verbose 模式 | 0+ |
| MemPalace | 文件系统（.doit/docs/, .spec/archive/） | -1, 1, 2, 3, 8, resume |
