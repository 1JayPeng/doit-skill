# Subagent Orchestration

**纯 Claude Code 原生能力。无需外部插件或 skill。**

**环境要求：** Agent 工具需要 Claude 模型（Opus/Sonnet/Haiku）才能启动子 agent。在 Qwen 等非 Claude 模型环境下，Agent 调用会返回模型不存在的错误。Subagent 编排模式在 Claude 模型环境下正常工作。

Claude Code 内置 `Agent` 工具允许启动独立 agent 处理子任务。每个 agent 有独立的上下文窗口、独立的工具调用链、独立的工作目录（可选 worktree 隔离）。

## Why Subagents

| 问题 | 无 subagent | 有 subagent |
|------|------------|-------------|
| 并行探索 | 顺序搜索，上下文膨胀 | 多 agent 并行，结果汇总 |
| 大文件分析 | 全量读入上下文 | agent 在 sandbox 中处理，只返回摘要 |
| 长时间任务 | 主流程阻塞 | 后台 agent + 通知机制 |
| 隔离需求 | 主上下文被污染 | agent 独立上下文，只传结果 |

## Agent Tool Primitives

### Basic Launch

```
Agent({
  description: "3-5词任务描述",
  prompt: "完整的任务指令",
  subagent_type: "general-purpose",  // 或 claude, Explore, Plan
  run_in_background: false
})
```

### Background Launch (Non-blocking)

```
Agent({
  description: "Research async patterns",
  prompt: "搜索代码库中所有 async/await 的使用模式...",
  subagent_type: "Explore",
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
  subagent_type: "Explore"
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
Agent({ description: "Analyze impact on module A", prompt: "使用 tokensave_context 分析修改模块 A 的影响...", run_in_background: true })
Agent({ description: "Analyze impact on module B", prompt: "使用 tokensave_context 分析修改模块 B 的影响...", run_in_background: true })

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
Agent({ description: "Complexity analysis", prompt: "使用 tokensave_complexity 分析复杂度...", run_in_background: true })
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
  prompt: "使用 tokensave_complexity 全面分析代码复杂度...",
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
| 需要用户输入 | agent 无法交互 | 主流程 + AskUserQuestion |
| 简单一行命令 | 启动 agent 开销 > 直接执行 | 直接 Bash |
| 需要实时反馈 | agent 结果延迟 | 主流程直接执行 |
| 上下文 < 500 行的读取 | agent 开销不值得 | 直接 Read |

## Subagent + Tokensave (Best Practice)

在 tokensave 启用项目中，subagent 应使用 tokensave 工具：

```
Agent({
  description: "Explore authentication code",
  prompt: "使用 tokensave_context 研究认证代码。查询 'authentication middleware'。",
  subagent_type: "Explore",
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

## Complete Example: Phase 1 Spec with Subagents

```
// === Phase 1: Spec Generation ===

// Step 1: 并行研究（激进并行）
Agent({
  description: "Research competitive solutions",
  prompt: "使用 WebSearch 搜索 'user authentication best practices 2026'，汇总前 5 个方案...",
  subagent_type: "general-purpose",
  run_in_background: true
})

Agent({
  description: "Analyze existing auth code",
  prompt: "使用 tokensave_context 分析当前项目的认证代码。查找 middleware、token、session 相关符号...",
  subagent_type: "Explore",
  run_in_background: true
})

Agent({
  description: "Review security requirements",
  prompt: "使用 WebSearch 搜索 'OWASP authentication requirements 2026'，提取关键安全要求...",
  subagent_type: "general-purpose",
  run_in_background: true
})

// 主流程在等待期间：准备 spec 模板、检查 MemPalace 历史
mempalace_search(query="authentication spec", limit=3)

// Step 2: 研究 agent 完成后，汇总结果
// Step 3: 综合研究结果 + 用户输入 -> 撰写 spec
// Step 4: 保存 .spec/current.md
```
