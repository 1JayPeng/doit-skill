# Spec: Subagent Orchestration in Doit Workflow

## Context

Claude Code 内置 Agent 工具支持并行子任务、后台执行、worktree 隔离。当前 doit 工作流完全顺序执行——Phase 1 完成后才 Phase 2，Phase 2 完成后才 Phase 3。大量时间浪费在"等一个任务完成才能开始下一个"上。

**目标：** 利用原生 Agent 工具，在不增加任何外部插件的前提下，让 doit 工作流能够并行执行独立任务。

## Design Decisions (Grill Results)

| Question | Decision | Why |
|----------|----------|-----|
| 新 phase 还是增强现有？ | 增强现有 phase | subagent 是执行机制，不是独立阶段 |
| 成本上限？ | 按需并行，无硬性上限 | 用户选择激进策略；haiku 做简单任务省钱 |
| agent 间通信？ | 通过文件 + git | agent 上下文独立，共享状态通过文件系统 |
| 失败处理？ | agent 失败 -> 主流程捕获错误 -> 重试或降级 | 不阻塞整个工作流 |
| 与现有铁律关系？ | 完全兼容 | Background Execution 铁律 -> run_in_background |

## Acceptance Criteria

### REQ-001: Parallel Research in Phase 1 (Spec Generation)

**When:** Phase 1 需要研究多个独立方向（竞品分析、现有代码扫描、安全要求）

**Behavior:**
- 检测到 2+ 个独立研究任务 -> 并行启动对应数量 agent
- 简单搜索用 haiku 模型，复杂分析用 opus
- 每个 agent 在后台运行，完成后自动通知
- 主流程汇总所有 agent 结果，生成 spec

**Verification:** Phase 1 研究时间从串行 3 次 API 调用 -> 1 次并行调用

### REQ-002: Parallel Code Analysis in Phase 2 (Plan)

**When:** Phase 2 需要分析多个模块的影响范围

**Behavior:**
- 每个模块一个 agent，使用 tokensave_context 获取代码图
- Agent 类型用 Plan，产出架构设计建议
- 主流程综合所有分析结果，生成实现计划

**Verification:** 多模块影响分析从 N 个串行 tokensave 调用 -> N 个并行 agent

### REQ-003: Independent REQ Execution in Phase 3

**When:** Phase 3 的 REQ 之间无代码依赖

**Behavior:**
- 检测 REQ 依赖关系（通过 tokensave 代码图）
- 无依赖的 REQ -> 并行 agent 处理，每个 agent 用 worktree 隔离
- 有依赖的 REQ -> 顺序执行
- 每个 agent 完成后 commit 到 worktree 分支

**Verification:** 3 个独立 REQ 从串行 15min -> 并行 ~5min

### REQ-004: Parallel Review in Phase 5-6

**When:** Phase 5-6 需要多维度审查（安全、架构、复杂度）

**Behavior:**
- 安全审查 agent（使用 tokensave_unsafe_patterns）
- 架构审查 agent（使用 tokensave_dsm, tokensave_coupling）
- 复杂度审查 agent（使用 tokensave_complexity）
- 3 个 agent 并行，主流程汇总审查报告

**Verification:** 审查时间从 3 个串行 -> 1 个并行

### REQ-005: Background Agent with Main Flow Continuation

**When:** 长时间任务（build、test、deploy）需要后台运行

**Behavior:**
- 启动后台 agent 处理长时间任务
- 主流程继续做其他工作（文档更新、代码审查准备）
- 后台 agent 完成 -> 通知 -> 主流程检查结果
- 符合 Background Execution 铁律

**Verification:** 长时间任务不阻塞主流程

### REQ-006: Agent Failure Handling

**When:** 任何 agent 执行失败（超时、token 耗尽、工具错误）

**Behavior:**
- Agent 失败 -> 返回错误信息给主流程
- 主流程记录失败原因
- 可重试（最多 2 次）或降级（主流程自己执行该任务）
- 不阻塞其他并行 agent

**Verification:** 单个 agent 失败不影响其他 agent 和主流程

## Out of Scope

- Agent 之间的直接通信（通过文件协调，不直接对话）
- 跨会话的 agent 状态恢复（每个会话重新 spawn）
- 自定义 agent 类型（使用内置的 5 种类型）
- Agent 的 token 预算控制（未来可以加，当前按需）

## Files to Modify

| File | Change |
|------|--------|
| `subagent.md` | 完整 subagent 使用指南（已创建） |
| `SKILL.md` | 添加 subagent orchestration 章节 |
| `execute.md` | Phase 3 添加 subagent 并行执行模式 |
| `spec.md` | Phase 1 添加并行研究模式 |
| `plan.md` | Phase 2 添加并行代码分析 |
| `review.md` | Phase 5 添加并行审查模式 |
| `shared/review-simplify.md` | Phase 6 添加并行简化模式 |
| `background-process.md` | 添加 agent 作为后台执行的一种模式 |
| `errors.md` | 添加 agent 失败处理 |
| `principles.md` | 添加 subagent 并行原则 |
| `README.md` | 添加 subagent 功能介绍 |
| `README_ZH.md` | 同上，中文版 |
