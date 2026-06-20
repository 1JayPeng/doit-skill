# Subagent Orchestration

**纯 Claude Code 原生能力。无需外部插件或 skill。**

**环境要求：** Agent 工具需要 Claude 模型（Opus/Sonnet/Haiku）才能启动子 agent。在 Qwen 等非 Claude 模型环境下，Agent 调用会返回模型不存在的错误。Subagent 编排模式在 Claude 模型环境下正常工作。

**配置开关：** 读取 `.doit/config.yaml` 中 `subagent.enabled`。默认 `false`（禁用）。设置为 `true` 启用子代理编排。通过 `setup.sh` 安装时交互式选择，或手动编辑 `~/.doit/config.yaml`。

Claude Code 内置 `Agent` 工具允许启动独立 agent 处理子任务。每个 agent 有独立的上下文窗口、独立的工具调用链、独立的工作目录（可选 worktree 隔离）。

## Subagent Tool Access

**子代理通过 `general-purpose` agent type 获得完整工具权限。** 工具使用是省 token 的关键（codegraph 替代 Explore agent，context-mode 替代 Bash）。

| 工具 | 用途 | 省 token 效果 |
|------|------|--------------|
| codegraph | 代码图分析（符号搜索、调用关系、影响范围） | 替代 grep+Read，减少 60-80% 上下文读取 |
| context-mode | 会话上下文管理（ctx_execute, ctx_search） | 自动索引命令输出，语义搜索替代 grep |
| MemPalace | 跨会话语义记忆（spec、决策、实现笔记） | 避免重复研究，跨会话上下文恢复 |
| Read/Edit/Write | 文件读写 | 精确编辑，减少全量读取 |
| Bash | 命令行执行 | 编译、测试、git 操作 |
| `[[USER:ask]]` | 交互式提问 | 非阻塞式用户决策 |
| Agent | 嵌套子代理 | 递归并行（慎用，token 成本高） |

**子代理可用所有 Claude Code 工具。** 通过 `subagent_type: "general-purpose"` 获得与主代理相同的工具集。工具链正确配置是子代理效率的关键 — 有 codegraph 的子代理比只有 Bash+Read 的子代理快 3-5 倍。

## Why Subagents

| 问题 | 无 subagent | 有 subagent |
|------|------------|-------------|
| 并行探索 | 顺序搜索，上下文膨胀 | 多 agent 并行，结果汇总 |
| 大文件分析 | 全量读入上下文 | agent 在 sandbox 中处理，只返回摘要 |
| 长时间任务 | 主流程阻塞 | 后台 agent + 通知机制 |
| 隔离需求 | 主上下文被污染 | agent 独立上下文，只传结果 |

**Cost:** Each subagent = separate API call. 2 parallel agents = ~2x tokens, but 50-70% faster completion. Control via `subagent.enabled` in `.doit/config.yaml`.

## Agent Tool Primitives

### Basic Launch

```
Agent({
  description: "3-5词任务描述",
  prompt: "完整的任务指令",
  subagent_type: "general-purpose",  // 或 claude, Plan
  run_in_background: false
})
```

### Background Launch (Non-blocking)

```
Agent({
  description: "Research async patterns",
  prompt: "搜索代码库中所有 async/await 的使用模式...",
  subagent_type: "general-purpose",
  run_in_background: true
})
// 主流程继续执行。agent 完成后自动通知。
```

### Worktree Isolation (Independent Git Branch)

```
Agent({
  description: "Implement feature branch",
  prompt: "在独立分支上实现 X 功能...",
  subagent_type: "claude",
  isolation: "worktree"
})
// agent 在 .claude/worktrees/ 下工作，不污染主分支
```

### 铁律 — 继承主对话模型

**绝不指定 `model` 参数。Subagent 继承主对话的模型。**

```
Agent({
  description: "Complex architecture review",
  prompt: "Review the architecture...",
  subagent_type: "Plan"
  // 不指定 model -> 继承主对话模型
})

Agent({
  description: "Quick file search",
  prompt: "Find all usages of...",
  subagent_type: "general-purpose"
  // 不指定 model -> 继承主对话模型
})
```

**为什么：**
- 指定 `model: "haiku"` 或 `model: "opus"` 会导致模型不存在错误（当前环境可能不支持该模型）
- 主对话模型已经是最优选择，subagent 继承即可
- 减少配置表面，降低出错率

### SendMessage (Continue Agent)

```
// 向已启动的 agent 发送后续指令
SendMessage(to="<agent_id_or_name>", message="新的指令...")
```

## Available Agent Types

| Type | Use | Tools |
|------|-----|-------|
| **general-purpose** | 通用研究、搜索、多步任务 | 全部 |
| **claude** | 默认，任何不匹配特定类型的任务 | 全部 |
| **Explore** | 快速只读代码搜索 | 除 Agent、Edit、Write 外 |
| **Plan** | 架构设计、实现计划 | 除 Agent、Edit、Write 外 |
| **claude-code-guide** | Claude Code CLI 相关问题 | Bash, Read, WebFetch, WebSearch |

**⚠️ 重要：Explore agent 内部硬编码了 haiku 模型，不继承主对话模型。** 在非 Claude 模型环境下，Explore agent 会失败。用 `general-purpose` 替代 Explore。

**铁律：所有 subagent 调用必须使用 `general-purpose` 或 `Plan` 类型，绝不使用 `Explore`。**

### 铁律 — 同文件冲突零容忍

**多个 subagent 绝不允许并行修改同一文件。违反此规则 = 数据丢失。**

```
// ❌ 错误：两个 agent 修改同一文件
Agent({ description: "Fix auth middleware", prompt: "...修改 src/auth/middleware.rs...", run_in_background: true })
Agent({ description: "Add rate limiting", prompt: "...修改 src/auth/middleware.rs...", run_in_background: true })
// → 第二个 agent 的修改覆盖第一个，或产生不可预测的合并冲突

// ✅ 正确：文件无交集 → 并行
Agent({ description: "Fix auth middleware", prompt: "...修改 src/auth/middleware.rs...", run_in_background: true })
Agent({ description: "Add rate limiting", prompt: "...修改 src/api/rate-limit.rs...", run_in_background: true })

// ✅ 正确：同文件 → 串行
Agent({ description: "Fix auth middleware", prompt: "...修改 src/auth/middleware.rs..." })  // 阻塞直到完成
Agent({ description: "Add rate limiting", prompt: "...修改 src/auth/middleware.rs..." })   // 第一个完成后执行
```

**执行流程（主流程责任）：**

1. **Phase 2 规划时，为每个 REQ 列出 target_files** — 通过 `codegraph_impact` 或 `codegraph_context` 确定每个 REQ 影响哪些文件
2. **构建文件分配表** — REQ-001 → [file_a, file_b], REQ-002 → [file_c], REQ-003 → [file_a, file_d]
3. **检查文件交集** — REQ-001 和 REQ-003 共享 file_a → 不能并行
4. **无交集 → 并行派发** | **有交集 → 串行执行（文件多的 agent 先跑）**

**Worktree 隔离模式同样适用此规则：**

```
Agent({ description: "Implement REQ-001", prompt: "...", isolation: "worktree" })
Agent({ description: "Implement REQ-002", prompt: "...", isolation: "worktree" })
// 两个 worktree 各自修改不同文件 → 并行 OK
// 完成后主流程合并：
//   git merge worktree-req-001 --no-edit
//   git merge worktree-req-002 --no-edit
//   → 冲突？ → git diff --name-only --diff-filter=U → 解决
```

**只读操作天然安全：** Phase 5 的并行 review（security, architecture, complexity）只做 codegraph 查询，不写文件 → 无需检查文件交集。

**违反后果：**
- 同一文件并行写入 → 后完成的 agent 覆盖先完成的 → 工作丢失
- Worktree 合并冲突 → 主流程额外工作量解决 → 延迟交付
- Edit 工具 "string not found" 错误 → agent 失败 → 浪费 token

**检测机制（主流程在派发前执行）：**

```
伪代码：
agent_file_map = {}  # agent_id -> [files]
for each agent_to_launch:
  files = parse_target_files(agent.prompt)
  for already_launched_agent in launched_agents:
    intersection = files ∩ agent_file_map[already_launched_agent]
    if intersection not empty:
      # 冲突！串行执行此 agent，不并行
      queue_for_sequential(agent)
      break
  else:
    # 无冲突，安全并行
    launch_parallel(agent)
    agent_file_map[agent.id] = files
```


## Per-Phase Subagent Patterns

### Phase 1: Spec Generation

**并行研究 + 规范撰写：**

```
// 并行启动多个研究 agent
Agent({ description: "Research existing solutions", prompt: "...", run_in_background: true })
Agent({ description: "Analyze user requirements", prompt: "...", run_in_background: true })
Agent({ description: "Find edge cases", prompt: "...", run_in_background: true })

// 主流程：等待研究完成后，汇总结果，撰写 spec
```

### Phase 2: Plan with Code Graph

**并行代码分析：**

```
Agent({ description: "Analyze impact on module A", prompt: "使用 codegraph_context 分析修改模块 A 的影响...", run_in_background: true })
Agent({ description: "Analyze impact on module B", prompt: "使用 codegraph_context 分析修改模块 B 的影响...", run_in_background: true })

// 主流程：综合两个分析结果，产出实现计划
```

### Phase 3: Execute

**并行测试编写：**

```
// 一个 agent 写测试（RED），一个 agent 准备实现上下文
Agent({ description: "Write failing tests for REQ-001", prompt: "...", run_in_background: true })
// 主流程：准备实现代码（GREEN）
// 测试 agent 完成后，运行测试
```

**注意：Phase 3 的并行需要谨慎。写同一文件的 agent 不能并行。**

### Phase 4-7: E2E and Review

**并行 E2E 测试执行：**

```
// 不同测试套件并行运行
Agent({ description: "Run L0 happy path tests", prompt: "...", run_in_background: true })
Agent({ description: "Run L1 boundary tests", prompt: "...", run_in_background: true })
```

**并行代码审查：**

```
Agent({ description: "Security review", prompt: "审查安全漏洞...", subagent_type: "general-purpose", run_in_background: true })
Agent({ description: "Architecture review", prompt: "审查架构一致性...", subagent_type: "Plan", run_in_background: true })
Agent({ description: "Complexity analysis", prompt: "使用 codegraph 分析复杂度...", run_in_background: true })
```

### Phase 8: Commit + Push

Subagent 在 Phase 8 中作用有限。主流程处理 git 操作更直接。

## Parallel Execution Strategies

### Fan-Out (并行分发)

适用于独立任务的并行：

```
// 3 个独立研究任务并行
Agent({ description: "Task A research", prompt: "...", run_in_background: true })
Agent({ description: "Task B research", prompt: "...", run_in_background: true })
Agent({ description: "Task C research", prompt: "...", run_in_background: true })
// 主流程继续其他工作，等待 agent 完成通知
```

### Pipeline (流水线)

适用于有依赖的任务链：

```
// Stage 1: 研究 -> Stage 2: 计划 -> Stage 3: 实现
Agent({ description: "Research phase", prompt: "..." })  // 阻塞直到完成
// 用研究结果启动计划 agent
Agent({ description: "Plan phase", prompt: "基于研究结果: {research_result}，制定计划..." })
// 用计划启动实现 agent
Agent({ description: "Implement phase", prompt: "基于计划: {plan}，实现...", isolation: "worktree" })
```

### Map-Reduce (分发 + 汇总)

适用于大规模代码分析：

```
// Map: 并行分析多个模块
Agent({ description: "Analyze module 1", prompt: "...", run_in_background: true })
Agent({ description: "Analyze module 2", prompt: "...", run_in_background: true })
Agent({ description: "Analyze module 3", prompt: "...", run_in_background: true })

// Reduce: 主流程汇总所有结果
// 当所有 agent 完成后，综合报告
```

## Cost Management

并行策略下的成本优化：

| 策略 | 效果 |
|------|------|
| **继承主对话模型** | 不指定 model 参数，避免模型不存在错误 |
| **background agent 不阻塞** | 利用等待时间做其他工作 |
| **SendMessage 复用上下文** | 比重新 spawn 省 token |
| **并行减少总时间** | 3 个并行 agent = 1 个串行 agent 的时间

## Integration with Background Execution (铁律)

Subagent 与后台执行铁律协同：

```
// 长时间 agent 任务 -> 后台运行
Agent({
  description: "Full codebase complexity audit",
  prompt: "使用 codegraph 全面分析代码复杂度...",
  subagent_type: "general-purpose",
  run_in_background: true    // 符合铁律：不阻塞主流程
})

// 主流程继续做其他工作
// 当 agent 完成通知时，读取结果并继续
```

## Integration with Commit + Push (铁律)

Worktree 隔离的 agent 完成工作后，必须 commit + push：

```
Agent({
  description: "Implement feature X",
  prompt: "实现功能 X，完成后 git commit + push...",
  subagent_type: "claude",
  isolation: "worktree"
})
// agent 的 prompt 中应包含 commit + push 的指令
// 主流程在 agent 完成后，检查 worktree 的 git 状态
```

## When NOT to Use Subagents

| 场景 | 原因 | 替代 |
|------|------|------|
| 修改同一文件 | 冲突风险 | 主流程顺序执行 |
| 需要用户输入 | agent 无法交互 | 主流程 + `[[USER:ask]]` |
| 简单一行命令 | 启动 agent 开销 > 直接执行 | 直接 Bash |
| 需要实时反馈 | agent 结果延迟 | 主流程直接执行 |
| 上下文 < 500 行的读取 | agent 开销不值得 | 直接 Read |

## Subagent + CodeGraph (Best Practice)

在 codegraph 启用项目中，subagent 应使用 codegraph 工具：

```
Agent({
  description: "Explore authentication code",
  prompt: "使用 codegraph_context 研究认证代码。查询 'authentication middleware'。",
  subagent_type: "general-purpose",
  run_in_background: true
})
```

## Subagent + Context-Mode

agent 可以使用 context-mode 工具索引内容，主流程后续通过 ctx_search 检索：

```
// agent 索引文档
Agent({
  description: "Index API documentation",
  prompt: "使用 ctx_fetch_and_index 获取并索引 API 文档...",
  run_in_background: true
})

// 主流程搜索索引内容
ctx_search(queries=["authentication endpoint"])
```

## Error Handling

```
1. agent 启动失败 -> 降级到主流程直接执行
2. agent 超时 -> 检查 worktree 状态，恢复部分结果
3. agent 产生冲突 -> 主流程合并，解决冲突
4. worktree 清理 -> agent 完成后自动清理（如无变更）
```

## Conductor Orchestration Mode

**核心范式：** 主代理 = Project Manager，子代理 = 团队成员。每个子代理有独立 worktree，遵循适配版 doit 工作流。主代理负责 Phase 1-2（Spec + Plan）、Phase 4-10（E2E + Review + Merge + Compact）。子代理负责 Phase 3（Execute）的 TDD 循环。

**参考模型：** 开源团队工作流（Plane、GitHub PR 流程）。子代理 commit → 主代理 review → 主代理 merge。

详见 [subagent-architecture.md](subagent-architecture.md)。

**主代理 = 纯主管（conductor），不做任何实现工作。** 主代理负责调度、监督、轮询、汇总、spec 对齐。

### Why Conductor Mode

| 问题 | 无 conductor | 有 conductor |
|------|-------------|-------------|
| 主代理角色混乱 | 有时自己做，有时调度 | 纯主管，职责清晰 |
| 子代理卡住无人管 | 等超时或永远卡住 | 鞭子机制逐步升级 |
| 波次混乱 | 全部并行或全部串行 | REQ 依赖图 -> 自动波次 |
| 结果不可靠 | 子代理偷懒/偏离无检测 | 深度监督 + spec 对齐 |
| 质量失控 | 跳过 TDD、跳过 commit | 监督铁律遵守 |

### Conductor 责任矩阵

**主代理（Conductor）DO:**
- 构建 REQ 依赖图 -> 推导波次
- 派发子代理（每个 REQ 一个子代理）
- 轮询子代理进度
- 监督子代理工具使用和铁律遵守
- 触发鞭子机制（SendMessage 催促 -> 杀死重启）
- 汇总所有子代理结果
- 对照 spec 逐项检查（完成矩阵）
- 交付 Review + Simplify

**主代理（Conductor）DON'T:**
- 编写实现代码
- 修改业务逻辑文件
- 代替子代理做 TDD 循环
- 代替子代理写 commit
- 在子代理运行时做无关工作

**子代理 DO:**
- 执行分配的 REQ（完整 TDD 循环）
- 使用正确工具（codegraph, context-mode, mempalace）
- 遵守所有 doit 铁律
- 完成后 commit + push（如果 worktree 隔离）
- 返回结构化结果（文件列表、测试状态、工具合规性）

**子代理 DON'T:**
- 修改超出 REQ 范围的文件
- 跳过测试
- 跳过 commit

### Wave Scheduling — 波次调度器

**目标：** REQ 依赖图 -> 自动推导并行波次。同一波次内并行，波次间串行。

**Phase 2 规划时，为每个 REQ 标注依赖：**

```
REQ-001: 创建用户模型, dependencies: []
REQ-002: 创建认证 API, dependencies: [REQ-001]
REQ-003: 创建用户配置 API, dependencies: []
REQ-004: 集成认证中间件, dependencies: [REQ-002]
```

**波次推导算法（拓扑排序）：**

```
伪代码：
waves = []
resolved = {}
remaining = all_reqs.copy()

while remaining not empty:
  wave = []
  for req in remaining:
    if all(dep in resolved for dep in req.dependencies):
      wave.append(req)

  # 文件冲突检查：同文件不能并行
  parallel_groups = split_by_file_conflict(wave)
  for group in parallel_groups:
    waves.append(group)

  for req in wave:
    resolved[req] = true
    remaining.remove(req)

return waves
```

**输出示例：**

```
Wave 1: [REQ-001, REQ-003]     # 无依赖，并行
Wave 2: [REQ-002]               # 依赖 REQ-001
Wave 3: [REQ-004]               # 依赖 REQ-002
```

**执行模板：**

```
for wave in waves:
  # 并行派发本波次所有 REQ
  for req in wave:
    Agent({
      description: req.description,
      prompt: build_conductor_prompt(req, spec, context),
      subagent_type: "general-purpose",
      isolation: "worktree",
      run_in_background: true
    })

  # 轮询本波次全部完成
  wait_for_all(wave)

  # 监督检查
  for req in wave:
    result = collect_result(req)
    if not validate_result(result, req):
      handle_failure(req, result)

  # 全部通过 -> 下一波次
```

### Deep Supervision — 深度监督机制

**监督清单（每个子代理完成后检查）：**

```
[Supervision Checklist]
REQ-XXX: <description>

工具使用:
  [ ] 使用 codegraph_context/codegraph_search（而非 Explore agent）
  [ ] 使用 context-mode 工具（ctx_search, ctx_execute）
  [ ] 未使用被禁止的工具（Bash 用于大量输出）

TDD 循环:
  [ ] 先写测试（RED）
  [ ] 实现通过测试（GREEN）
  [ ] 运行测试验证（测试通过）

铁律遵守:
  [ ] git commit + push 完成
  [ ] MemPalace 读写（如果可用）
  [ ] 后台执行铁律（>10s 命令后台化）
  [ ] 未修改超出 REQ 范围的文件

产出质量:
  [ ] 修改文件列表与 Phase 2 计划一致
  [ ] 测试覆盖率 > 0
  [ ] 无编译错误
```

**监督执行方式：**

子代理返回结果必须是结构化格式：

```
[Agent Result]
REQ: REQ-001
Status: PASS | FAIL | PARTIAL
Files Modified: [file1, file2]
Tests: PASS (3/3) | FAIL (1/3)
Commit: abc1234 (pushed)
Tools Used: [codegraph_context, Edit, Bash]
Iron Rules Violated: [] | [detail]
Notes: <optional>
```

主代理根据结构化结果填充监督清单。发现违规 -> 记录 -> 在 Review 阶段修复。

### Whip Mechanism — 鞭子机制

**三级升级：** 子代理超时/卡住/偏离 -> 逐步升级干预。

```
Level 1 — SendMessage 催促:
  触发条件: 超过预期时间 50% 未返回
  动作: SendMessage(to=agent_id, message="进度检查：你目前的进展如何？列出已完成和待完成项。")
  预期: 子代理返回进度报告

Level 2 — 修正指令:
  触发条件: Level 1 后仍未返回，或进度报告显示偏离方向
  动作: SendMessage(to=agent_id, message="修正：你偏离了 REQ-XXX 的目标。正确做法是 [具体指令]。立即回到正轨。")
  预期: 子代理修正方向并继续

Level 3 — 杀死重启:
  触发条件: Level 2 后仍未返回，或确认子代理卡死
  动作:
    1. TaskStop(task_id=agent_id) — 终止子代理
    2. 分析失败原因（检查部分输出、worktree 状态）
    3. 修正 prompt（根据失败原因调整指令）
    4. 重新 spawn 新代理（使用修正后的 prompt）
  预期: 新代理完成 REQ
```

**预期时间计算：**

```
expected_time = base_time + (file_count * per_file_time) + (complexity_bonus)
base_time = 5 min (agent startup overhead)
per_file_time = 2 min per file
complexity_bonus = file_count * 1 min

timeout_threshold = expected_time * 1.5  # 50% buffer
```

**Prompt 修正策略（Level 3 重启时）：**

```
原始 prompt 分析：
  - 是否过于宽泛？ -> 缩小范围，指定具体文件
  - 是否缺少上下文？ -> 注入 codegraph_context 结果
  - 是否有歧义？ -> 明确 REQ 的 acceptance criteria

修正模板：
  "你之前在执行 REQ-XXX 时卡住了。失败原因：[原因分析]。
   修正后的指令：[具体化指令]。
   目标文件：[file1, file2]。
   验收标准：[acceptance criteria]。
   完成后返回结构化结果。"
```

### Result Collection — 结果汇总 + Spec 对齐

**每个子代理完成后记录：**

```
[Result Record]
REQ-001: 创建用户模型
  Status: PASS
  Files: [src/models/user.rs, tests/user_model_test.rs]
  Tests: PASS (5/5)
  Commit: a1b2c3d (pushed to feat/user-auth)
  Supervision: PASS (all checks)
  Spec Alignment: PASS

REQ-002: 创建认证 API
  Status: PARTIAL
  Files: [src/api/auth.rs]
  Tests: FAIL (2/4)
  Commit: e4f5g6h (pushed to feat/user-auth)
  Supervision: WARN (skipped mempalace)
  Spec Alignment: REQ-002.3 not implemented
```

**全部波次完成后 -> 完成矩阵：**

```
[Completion Matrix]
+---------+-----------+---------+----------+-------------+
| REQ     | Status    | Tests   | Commit   | Spec Align  |
+---------+-----------+---------+----------+-------------+
| REQ-001 | PASS      | 5/5     | a1b2c3d  | PASS        |
| REQ-002 | PARTIAL   | 2/4     | e4f5g6h  | PARTIAL     |
| REQ-003 | PASS      | 3/3     | i7j8k9l  | PASS        |
+---------+-----------+---------+----------+-------------+

Failed Items:
  - REQ-002: 2 tests failing -> fix needed
  - REQ-002: REQ-002.3 not implemented -> fix needed
  - REQ-002: MemPalace skipped -> low priority

Action: Dispatch fix agent for REQ-002, or handle in Review phase.
```

**交付流程：**

```
1. 所有 REQ PASS -> 合并所有 worktree 分支
2. 存在 FAIL/PARTIAL -> 生成修复任务 -> 派发修复 agent 或在 Review 阶段处理
3. 全部通过 -> 主代理宣布 Phase 3 完成 -> 交付 Phase 4 E2E
4. 主代理编写 Phase 3 完成摘要 -> 附加到工作流状态
```

### Rule Injection — 规则注入机制

**问题：** 子代理有独立上下文窗口，不会继承主对话的 SKILL.md 铁律。如果 prompt 中没有明确注入规则，子代理不知道规则存在。

**解决：** conductor prompt 模板必须注入完整铁律，而非简化摘要。子代理 prompt = 子代理的 SKILL.md。

**规则注入原则：**
1. **完整注入，不摘要** — 铁律原文注入，不是"遵守铁律"这样的模糊指令
2. **违规后果明确** — 每条铁律标注违反后果（鞭子机制触发）
3. **自我审计强制** — 返回前必须执行自我审计清单
4. **主代理同样受约束** — conductor 铁律在 SKILL.md 中，主代理必须遵守

### Conductor Prompt 模板（完整版）

**构建子代理 prompt：**

```
build_conductor_prompt(req, spec, context):
  return f"""
  ## 任务：{req.description}
  ## REQ ID: {req.id}
  ## 验收标准：
  {req.acceptance_criteria}

  ## 目标文件（只修改这些文件，超出范围 = 违规）：
  {req.target_files}
  ## 依赖：{req.dependencies}（已完成）

  ## 上下文：
  {context}  # codegraph_context 结果

  ## ===== 铁律（必须遵守，违反将触发鞭子机制） =====

  ### 铁律 1：工具使用规范
  - MUST 使用 codegraph_context 理解代码
  - MUST 使用 codegraph_search 查找符号
  - MUST 使用 context-mode 工具（ctx_search, ctx_execute）管理上下文
  - MUST NOT 使用 Explore agent（使用 general-purpose 替代）
  - MUST NOT 使用 Bash 处理大量输出（>20 行用 context-mode）
  - 违反后果：Level 2 修正指令 -> 强制使用正确工具

  ### 铁律 2：TDD 循环不可跳过
  - Step 1: 编写测试（RED）— 测试必须失败
  - Step 2: 编写最少实现（GREEN）— 测试必须通过
  - Step 3: 运行测试验证 — 确认通过
  - 禁止先写实现再补测试
  - 禁止跳过测试
  - 违反后果：Level 3 杀死重启，prompt 中加粗 TDD 步骤

  ### 铁律 3：后台执行
  - >10s 命令：必须使用 run_in_background=true 或 &
  - >5min 命令：必须使用 tmux + Monitor
  - 禁止空等长时间命令
  - 违反后果：Level 1 SendMessage 催促

  ### 铁律 4：Commit + Push 必须完成
  - 工作完成后：git add -> git commit -> git push
  - commit message 格式：type: description
  - 禁止只 commit 不 push
  - 违反后果：Level 2 SendMessage 指导完成

  ### 铁律 5：MemPalace 读写对称
  - 如果 MemPalace 工具可用：必须读写
  - [MP-READ] 搜索相关历史
  - [MP-WRITE] 写入实现摘要
  - 如果 MemPalace 不可用（工具报错）：静默跳过
  - 违反后果：低优先级，记录在 review 清单

  ### 铁律 6：同文件不并行
  - 你独占你的目标文件
  - 不要修改目标文件列表之外的文件
  - 如果必须修改额外文件：在结果中声明
  - 违反后果：Level 2 修正指令

  ### 铁律 7：文件范围不超出 REQ
  - 只修改目标文件列表中指定的文件
  - 禁止"顺便"修改其他文件
  - 禁止添加未在 spec 中描述的功能
  - 违反后果：Level 2 修正指令

  ### 铁律 8：危险操作保护
  - 禁止执行任何数据库删除操作（DROP TABLE, TRUNCATE, DELETE 无 WHERE）
  - 禁止使用 rm -rf / rm -r / rm -f 删除文件
  - 禁止 git push --force / git reset --hard / git clean -f
  - 如需删除，先通过 `[[USER:ask]]` 向用户确认
  - 违反后果：Level 3 杀死重启

  ## ===== 自我审计（返回前必须执行） =====

  在返回 [Agent Result] 之前，逐项检查：

  [Self-Audit]
  1. 工具使用：我使用了 codegraph 而非 Explore？[Y/N]
  2. TDD 循环：我先写测试（RED）再实现（GREEN）？[Y/N]
  3. 测试通过：所有测试都通过了？[Y/N]
  4. Commit + Push：我完成了 commit 和 push？[Y/N]
  5. 文件范围：我只修改了目标文件？[Y/N]
  6. 后台执行：长时间命令使用了后台执行？[Y/N]
  7. MemPalace：我执行了 MP 读写（如果可用）？[Y/N]
  8. 危险操作：我没有执行任何未确认的危险操作？[Y/N]

  任何 N -> 先修复，再返回。不要带着 N 返回。

  ## 返回格式：
  完成后返回以下结构化结果：
  [Agent Result]
  REQ: {req.id}
  Status: PASS | FAIL | PARTIAL
  Files Modified: [...]
  Tests: PASS (X/Y) | FAIL (X/Y)
  Commit: <hash> (pushed to <branch>)
  Tools Used: [...]
  Iron Rules Violated: [] | [rule_number: detail]
  Self-Audit: [8/8 PASS] | [X/8 PASS, failed: rule_Y]
  Notes: <optional>
  """
```

### Conductor Self-Check — 主代理自我约束

**主代理（conductor）同样受铁律约束。以下清单在 SKILL.md 中定义，conductor 必须遵守：**

```
[Conductor Self-Check]
每启动一个波次前：
  [ ] 我没有编写任何实现代码（纯主管角色）
  [ ] 我构建了 REQ 依赖图（不是猜测）
  [ ] 我检查了文件冲突（同文件不并行）
  [ ] 子代理 prompt 包含了完整铁律（不是简化摘要）

每收到子代理结果后：
  [ ] 我执行了深度监督清单（不是只看 PASS/FAIL）
  [ ] 我检查了自我审计结果（Self-Audit 项）
  [ ] 违规项已记录并计划修复

鞭子机制触发时：
  [ ] Level 1 -> Level 2 -> Level 3 按顺序升级（不跳级）
  [ ] Level 3 重启前分析了失败原因（不是盲目重启）
  [ ] Prompt 修正针对具体失败原因（不是通用模板）

波次全部完成后：
  [ ] 完成矩阵已构建（所有 REQ x 所有检查项）
  [ ] FAIL 项已生成修复任务
  [ ] 修复完成前不交付 Review
```

**为什么需要主代理自我约束：**
- 主代理有更强的能力诱惑（可以直接改代码比调度更快）
- 主代理跳过监督 -> 子代理质量失控 -> 最终返工成本 > 监督成本
- 主代理简化铁律注入 -> 子代理不知道规则 -> 违规率上升

### Cross-Review — 交叉审查机制

**核心：** 子代理 A 的代码由子代理 B 审查。主代理协调审查流程。

**为什么交叉审查 > 主代理审查：**

| 维度 | 主代理审查 | 交叉审查 |
|------|----------|----------|
| 上下文 | 主代理没写代码，不了解细节 | 审查子代理有完整实现上下文 |
| 偏见 | 主代理可能跳过审查（赶进度） | 子代理没有进度压力，专注质量 |
| 并行 | 串行（等主代理） | 并行（A 实现，B 审查） |
| 质量 | 主代理可能不深入代码 | 子代理专注审查，更深入 |

**交叉审查流程：**

```
1. 子代理 A 完成 REQ-001 -> commit 到 feat/req-001
2. 主代理启动子代理 B（审查模式）：
   Agent({
     description: "Cross-review REQ-001",
     prompt: build_reviewer_prompt(REQ-001, reviewer_agent="B"),
     subagent_type: "general-purpose",
     isolation: "worktree",  // 只读 worktree
     run_in_background: true
   })
3. 子代理 B 审查 REQ-001 的代码
4. 子代理 B 返回审查结果：
   [Review Result]
   REQ: REQ-001
   Reviewer: Agent B
   Status: APPROVE | REQUEST_CHANGES | REJECT
   Issues: [issue1, issue2, ...]
   Severity: BLOCKER | MAJOR | MINOR
   Suggestions: [suggestion1, ...]
5. 主代理根据审查结果决策：
   - APPROVE -> 合并 feat/req-001
   - REQUEST_CHANGES -> 派发修复任务给子代理 A
   - REJECT -> 杀死重启子代理 A
```

**审查子代理 Prompt 模板：**

```
build_reviewer_prompt(req, reviewer_agent):
  return f"""
  ## 任务：审查 {req.id} 的实现

  ## 被审查 REQ：
  {req.description}
  ## 验收标准：
  {req.acceptance_criteria}

  ## 审查清单：
  [ ] 代码实现了验收标准的所有条目？
  [ ] 代码没有实现验收标准之外的功能？
  [ ] 测试覆盖了核心功能？
  [ ] 没有安全漏洞（OWASP Top 10）？
  [ ] 没有重复代码？
  [ ] 没有过度抽象？
  [ ] 没有死代码？
  [ ] 错误处理合理？
  [ ] 代码可读性（命名、注释）？

  ## 审查规则：
  - 你只读代码，不修改代码
  - 发现问题 -> 记录，不修复
  - 严重问题（安全、数据丢失）-> REJECT
  - 小问题（命名、格式）-> REQUEST_CHANGES
  - 无问题 -> APPROVE

  ## 返回格式：
  [Review Result]
  REQ: {req.id}
  Reviewer: {reviewer_agent}
  Status: APPROVE | REQUEST_CHANGES | REJECT
  Issues: [...]
  Severity: BLOCKER | MAJOR | MINOR
  Suggestions: [...]
  """
```

**交叉审查配对规则：**
- REQ-001 由 REQ-002 的子代理审查（不同 REQ，无利益冲突）
- 如果只有 1 个 REQ，主代理审查
- 如果 REQ 有依赖关系（REQ-002 依赖 REQ-001），依赖方审查被依赖方（REQ-002 审查 REQ-001）

### Worktree Management — Worktree 管理

**子代理 worktree 生命周期：**

```
1. 主代理创建 worktree：
   git worktree add .claude/worktrees/req-001 feat/req-001

2. 子代理在 worktree 中工作：
   - 修改代码
   - 运行测试
   - git add + git commit（不 push）

3. 子代理完成 -> 返回 worktree 路径

4. 主代理审查 worktree：
   git diff main...feat/req-001  # 查看变更
   git log main..feat/req-001    # 查看提交

5. 主代理合并：
   git checkout main
   git merge feat/req-001 --no-edit  # 或 --squash

6. 主代理清理：
   git worktree remove .claude/worktrees/req-001
   git branch -d feat/req-001
```

**为什么子代理不 push：**
- push 是远程操作，网络不稳定
- 子代理失败 -> 远程有脏提交
- 主代理统一 push，保证原子性

**为什么子代理 commit：**
- commit 是本地操作，快速可靠
- commit 提供 git 历史，方便回滚
- commit 让主代理可以 diff 查看变更

### Cross-Review — 交叉审查机制

**目标：** 子代理 A 的代码由子代理 B 审查。避免自己写自己审的质量问题。

**流程：**

```
1. 子代理 A 完成 REQ-001 -> 返回 worktree 路径
2. 主代理启动子代理 B（审查角色）：
   Agent({
     description: "Cross-review REQ-001",
     prompt: build_review_prompt(REQ-001, worktree_A_path, spec),
     subagent_type: "general-purpose",
     run_in_background: true
   })
3. 子代理 B 审查：
   - 读取 REQ-001 的 diff（git diff main...feat/req-001）
   - 检查代码质量（重复、安全、架构）
   - 运行测试（cargo test / pytest）
   - 返回审查结果
4. 主代理根据审查结果：
   - PASS -> 合并 worktree
   - FAIL -> 派发修复任务给子代理 A（或新子代理）
```

**审查子代理 prompt 模板：**

```
build_review_prompt(req, worktree_path, spec):
  return f"""
  ## 审查任务：{req.description}
  ## REQ ID: {req.id}
  ## Worktree 路径：{worktree_path}
  ## 验收标准：{req.acceptance_criteria}

  ## 审查步骤：
  1. 进入 worktree：cd {worktree_path}
  2. 查看变更：git diff main...HEAD
  3. 运行测试：[测试命令]
  4. 检查代码质量：
     - 重复代码（相同逻辑出现多次）
     - 安全漏洞（OWASP Top 10）
     - 过度抽象（3 层函数包 1 个操作）
     - 死代码（未使用的函数、变量、import）
  5. 对照验收标准逐项检查

  ## 返回格式：
  [Review Result]
  REQ: {req.id}
  Verdict: PASS | FAIL
  Issues Found: [] | [issue1, issue2]
  Test Results: PASS (X/Y) | FAIL (X/Y)
  Recommendations: [] | [suggestion1, suggestion2]
  """
```

**交叉审查 vs 专用审查子代理：**

| 维度 | 交叉审查 | 专用审查子代理 |
|------|---------|--------------|
| Token 成本 | 低（复用实现子代理） | 高（额外子代理） |
| 审查质量 | 中（实现子代理可能不专业） | 高（专用审查子代理） |
| 复杂度 | 低（主代理协调简单） | 高（需要管理更多子代理） |
| 推荐场景 | 小项目（<5 REQ） | 大项目（>5 REQ） |

## Complete Example: Conductor Mode Phase 3

```
=== Scenario: 用户认证系统 ===
REQ-001: 创建用户模型, deps: [], files: [src/models/user.rs, tests/user_test.rs]
REQ-002: 创建认证 API, deps: [REQ-001], files: [src/api/auth.rs, tests/auth_test.rs]
REQ-003: 创建用户配置 API, deps: [], files: [src/api/config.rs, tests/config_test.rs]

=== Wave 1: REQ-001 + REQ-003 (并行) ===

Agent({
  description: "Implement REQ-001 user model",
  prompt: build_conductor_prompt(REQ-001, spec, codegraph_context("user model")),
  subagent_type: "general-purpose",
  isolation: "worktree",
  run_in_background: true
})

Agent({
  description: "Implement REQ-003 user config API",
  prompt: build_conductor_prompt(REQ-003, spec, codegraph_context("user config")),
  subagent_type: "general-purpose",
  isolation: "worktree",
  run_in_background: true
})

// Conductor 轮询 Wave 1...

[Wave 1 Result]
REQ-001:
  [Agent Result]
  REQ: REQ-001
  Status: PASS
  Files Modified: [src/models/user.rs, tests/user_test.rs]
  Tests: PASS (5/5)
  Commit: a1b2c3d (pushed to feat/user-auth)
  Tools Used: [codegraph_context, codegraph_search, Edit, Bash]
  Iron Rules Violated: []
  Self-Audit: [7/7 PASS]

REQ-003:
  [Agent Result]
  REQ: REQ-003
  Status: PASS
  Files Modified: [src/api/config.rs, tests/config_test.rs]
  Tests: PASS (3/3)
  Commit: i7j8k9l (pushed to feat/user-auth)
  Tools Used: [codegraph_context, Edit, Bash]
  Iron Rules Violated: []
  Self-Audit: [7/7 PASS]

// Conductor 监督：REQ-001 Self-Audit 7/7 PASS, 工具合规 -> PASS
// Conductor 监督：REQ-003 Self-Audit 7/7 PASS, 工具合规 -> PASS
-> Wave 1 complete, proceed to Wave 2

=== Wave 2: REQ-002 (依赖 REQ-001) ===

Agent({
  description: "Implement REQ-002 auth API",
  prompt: build_conductor_prompt(REQ-002, spec, codegraph_context("auth API") + REQ-001 result),
  subagent_type: "general-purpose",
  isolation: "worktree",
  run_in_background: true
})

// Conductor 轮询... REQ-002 超时预警 (expected 12min, elapsed 8min)
// Whip Level 1: SendMessage 催促
SendMessage(to="REQ-002-agent", message="进度检查：你目前的进展如何？列出已完成和待完成项。")
// REQ-002 返回：正在实现 login 端点，register 未完成
// -> 正常进度，继续等待

// REQ-002 完成
[Wave 2 Result]
REQ-002: PASS, Tests 4/4, Commit e4f5g6h, Supervision PASS
-> Wave 2 complete

=== Result Collection ===

[Completion Matrix]
+---------+--------+---------+----------+-------------+
| REQ     | Status | Tests   | Commit   | Spec Align  |
+---------+--------+---------+----------+-------------+
| REQ-001 | PASS   | 5/5     | a1b2c3d  | PASS        |
| REQ-002 | PASS   | 4/4     | e4f5g6h  | PASS        |
| REQ-003 | PASS   | 3/3     | i7j8k9l  | PASS        |
+---------+--------+---------+----------+-------------+

All REQ PASS -> Phase 3 complete -> 交付 Phase 4 E2E

[Whip Level 3 Example — 杀死重启]
// 假设 REQ-002 卡住，Level 1+2 均无效
TaskStop(task_id="REQ-002-agent")
// 分析：REQ-002 原 prompt 过于宽泛，未指定具体文件
// 修正 prompt -> 添加目标文件 + acceptance criteria
Agent({
  description: "Implement REQ-002 auth API (retry)",
  prompt: "你之前在实现 REQ-002 时卡住了。失败原因：prompt 过于宽泛。
          修正后的指令：实现 src/api/auth.rs 中的 login 和 register 端点。
          验收标准：login 返回 JWT token, register 创建用户并返回 201。
          完成后返回结构化结果。",
  subagent_type: "general-purpose",
  isolation: "worktree",
  run_in_background: true
})
```

## 交叉审查

子代理 A 实现 REQ，子代理 B 审查（只读，不修改）。主代理汇总审查报告，发回实现子代理修复。

**审查清单：** 正确性、安全漏洞（OWASP Top 10）、重复代码、过度抽象、测试覆盖率、死代码。

## Git 工作流

子代理在 worktree 中 commit（不 push，不 merge）。主代理收集结果后 squash merge 到功能分支，最后 push。

```bash
# 子代理
git checkout -b feat/req-001
# ... 实现 ...
git add . && git commit -m "feat: REQ-001 - <description>"

# 主代理
git merge feat/req-001 --no-edit --squash
git push origin feat/feature-name
```

## 最小上下文

子代理 prompt 只包含：REQ 描述、验收标准、目标文件列表、依赖状态、代码上下文、铁律、返回格式。不包含完整 spec、其他 REQ 细节、主对话历史。

## 进度暴露

子代理返回结构化进度报告：REQ ID、Phase、Progress %、ETA、Blockers、Files Modified、Tests 状态。主代理每 2 分钟轮询，超时触发鞭子机制。

## 交叉审查

子代理 A 实现 REQ，子代理 B 审查（只读，不修改）。主代理汇总审查报告，发回实现子代理修复。

**审查清单：** 正确性、安全漏洞（OWASP Top 10）、重复代码、过度抽象、测试覆盖率、死代码。

## Git 工作流

子代理在 worktree 中 commit（不 push，不 merge）。主代理收集结果后 squash merge 到功能分支，最后 push。

```bash
# 子代理
git checkout -b feat/req-001
# ... 实现 ...
git add . && git commit -m "feat: REQ-001 - <description>"

# 主代理
git merge feat/req-001 --no-edit --squash
git push origin feat/feature-name
```

## 最小上下文

子代理 prompt 只包含：REQ 描述、验收标准、目标文件列表、依赖状态、代码上下文、铁律、返回格式。不包含完整 spec、其他 REQ 细节、主对话历史。

## 进度暴露

子代理返回结构化进度报告：REQ ID、Phase、Progress %、ETA、Blockers、Files Modified、Tests 状态。主代理每 2 分钟轮询，超时触发鞭子机制。
