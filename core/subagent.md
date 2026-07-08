# Subagent Team Orchestration (Tool-Agnostic)

**Subagent orchestration is a native capability of most AI coding CLIs.**

**Config gate:** Read `.doit/config.yaml` `subagent.enabled`. Default `true` (enabled). Set to `false` to disable.

**Subagent tool access:** Subagents get full tool permissions. MCP tools (codegraph, context-mode, mempalace) are available to subagents. Subagent via `[[AGENT:spawn]]` gets same tool permissions as main agent. Agent type varies by CLI adapter — see [adapters/](../adapters/).

## 自主并行模式 — Autonomous Parallel (轻量级并行)

**与团队wave模式的区别：** 团队wave模式有层级分工（Architect→Developer→Reviewer），适用于完整的Feature开发。自主并行模式则是主代理**自主判断**任务可拆分，直接派发多个子代理并行执行，无需角色层级。

**核心铁律：主代理应该主动发挥主观能动性，不是被动等待指令。** 遇到以下情况，立即使用并行子代理而不需要用户明确要求。

### 何时触发自主并行

满足以下 ALL 条件时，主代理应立即使用并行子代理：

1. **任务可拆分** — 能分解为 2+ 独立子任务
2. **子任务无依赖** — 每个子任务不依赖其他子任务的结果
3. **目标文件不重叠** — 每个子任务修改的文件不冲突（同文件不并行铁律）
4. **主代理能验证结果** — 主代理有能力检查每个子代理的产出是否正确

### 适用场景

| 场景 | 拆分方式 | 子代理数量 |
|------|---------|-----------|
| 仓库全面审查 | 按模块/目录拆分 | 2-4 |
| 批量路径更新 | 按文件分组拆分 | 2-4 |
| 研究调研 | 按搜索维度拆分 | 2-3 |
| 代码审查 | 安全/架构/复杂度并行 | 2-3 |
| Bug调查（多模块） | 按影响范围拆分 | 2-3 |
| 文档同步更新 | 按文档类型拆分 | 2-3 |
| Feature开发（多REQ无依赖） | 按REQ拆分 | N |

### 不适用场景（主代理直接执行）

| 场景 | 原因 |
|------|------|
| 单文件修改 | 子代理开销不值得 |
| 简单命令 | 直接执行更快 |
| 需要用户输入 | 子代理无法交互 |
| 子任务有依赖 | 需要团队wave模式的波次调度 |
| 上下文 <500行 | 直接读取更高效 |

### 自主并行流程

```
Step 1: 主代理分析任务，识别可并行的子任务
Step 2: 确认文件不重叠（用 codegraph_impact 或 grep 检查）
Step 3: 并行派发子代理（background=true）
Step 4: 继续其他工作，等待子代理完成
Step 5: 收集结果，验证正确性
Step 6: 合并结果，报告用户
```

### 自主并行 vs 团队Wave模式 — 选择指南

```
任务需要完整的 Phase 1-7 工作流？
  ├─ YES → 团队Wave模式（Architect→Developer→Reviewer）
  └─ NO → 自主并行模式
       ├─ 子任务可独立拆分？
       │   ├─ YES → 并行子代理（2-N个，background=true）
       │   └─ NO → 主代理直接执行
```

### 提示词模板 — 自主并行子代理

```
你是主代理派发的并行子代理之一，负责 [具体子任务]。

任务范围：[描述具体要做的事]
目标文件：[文件列表]
约束：只修改目标文件，不修改范围外的文件

完成后返回：
[Subagent Result]
Task: [子任务描述]
Status: PASS | FAIL
Files Modified: [文件列表]
Summary: [做了什么，1-2句话]
Notes: [注意事项，可选]
```

## 三级团队模型 — Three-Tier Team

**核心思想：子代理不是"通用工人"，而是有明确角色的团队成员。** 主代理是 Conductor（项目经理），按阶段分配角色，每个角色子代理拥有专属职责。

### Tier 1 — 规划层 (Architect)

**职责：** 需求分析、代码图谱分析、执行计划。对应 Phase 1-2。

| 角色 | 职责 | 阶段 | 产出 |
|------|------|------|------|
| **Architect** | 需求分析 + 代码架构分析 + 执行计划 | Phase 1-2 | spec, plan, REQ dependency graph, wave schedule |

**Architect 子代理特征：**
- 读多写少，专注信息收集和分析
- 使用 `codegraph_context`, `codegraph_impact`, `codegraph_search` 做代码图谱分析
- 使用 `mempalace_search` 检索历史知识和决策
- 使用 Tavily MCP 或 WebSearch 搜索现有解决方案
- 产出结构化文档（`.spec/current.md`, plan, wave schedule）
- **不写业务代码，不做 TDD 循环**

### Tier 2 — 执行层 (Developer)

**职责：** TDD 循环实现。对应 Phase 3。

| 角色 | 职责 | 阶段 | 产出 |
|------|------|------|------|
| **Developer** x N | 每个 Developer 负责一个 REQ 的 TDD 实现 | Phase 3 | 通过测试的代码 + commit |

**Developer 子代理特征：**
- 严格按一个 REQ 工作，不越界
- 遵循 TDD 循环：CONTEXT → IMPLEMENT → RED → GREEN → REFACTOR → REVIEW+SIMPLIFY
- 拥有独立的 worktree（`worktree=true`），在独立分支上工作
- 完成后产出结构化 `[Agent Result]`
- **同文件不并行**：如果两个 REQ 修改同一文件，必须串行

### Tier 3 — 质量层 (Reviewer + Tester)

**职责：** E2E 测试、代码审查、简化。对应 Phase 4-7。

| 角色 | 职责 | 阶段 | 产出 |
|------|------|------|------|
| **Tester** | E2E 测试执行，L0-L3 测试用例运行 | Phase 4, 7 | 测试报告 |
| **Reviewer** | 代码审查、安全检查、架构一致性 | Phase 5 | 审查意见 |
| **Simplifier** | 重复代码消除、抽象层扁平化 | Phase 6 | 简化后代码 |

**质量层子代理特征：**
- 读优先，审查优先
- Tester 运行真实环境测试
- Reviewer 检查安全漏洞、架构一致性、复杂度
- Simplifier 消除重复、扁平化抽象、删除死代码
- **不可跳过**：Phase 6 (Simplify) 是硬门控

### 团队组合策略

根据功能复杂度选择团队规模：

```
Type S (simple): 无子代理，主代理直接执行
Type F (feature, <3 REQs): Conductor + Developer x N
Type F (feature, 3+ REQs): Conductor + Architect + Developer x N + Reviewer + Tester + Simplifier
Type B (bug): Conductor + diagnose skill
```

## 持续角色分配 — Persistent Role Assignment

**角色子代理在整个功能开发周期内驻留，不随波次释放。**

传统模式：每个波次结束释放子代理，下次波次重新创建。
持续模式：角色子代理在功能生命周期内保持活跃，通过 `[[AGENT:message]]` 接收新任务。

```
// 持续角色分配示例：
[[AGENT:spawn description="Architect - spec & plan" prompt="You are the Architect. Analyze requirements, build spec, create plan..." background=true]]
// Architect completes Phase 1-2

[[AGENT:message to=architect_id message="Phase 2 complete. Here is the wave schedule: [...]"]]
// Architect continues as observer, available for questions

// 波次 1: Developer-1 和 Developer-2 并行
[[AGENT:spawn description="Developer REQ-001" prompt="You are Developer-1. Implement REQ-001: ..." worktree=true background=true]]
[[AGENT:spawn description="Developer REQ-003" prompt="You are Developer-2. Implement REQ-003: ..." worktree=true background=true]]
// wait_for_all(wave 1)

// 波次 2: Developer-1 继续
[[AGENT:message to=developer1_id message="REQ-002 is next. Dependencies (REQ-001) completed. Target files: [...]"]]
// Developer-1 picks up next REQ without re-spawn
```

**优势：**
- 上下文保留：子代理已了解的代码架构无需重新解释
- 启动成本低：不需要重建 prompt
- 角色连续性：同一 Developer 按依赖顺序处理多个 REQ

**何时释放：** 功能完成（Phase 8 commit+push 后），或角色不再需要。

## Subagent Tool Access

| Tool | Purpose | Token Savings |
|------|---------|--------------|
| codegraph | Code graph analysis | Replaces grep+Read, 60-80% context reduction |
| context-mode | Session context management | Auto-index commands, semantic search |
| MemPalace | Cross-session semantic memory | Avoid重复 research, context recovery |
| FILE:read/edit/write | File operations | Precise edits, reduced reads |
| SHELL:run | Shell commands | Build, test, git |
| USER:ask | Interactive questions | Non-blocking user decisions |
| AGENT:spawn | Nested subagents | Recursive parallel (use carefully) |

## Why Subagents

| Problem | No subagent | With subagent (团队模式) |
|---------|------------|------------------------|
| 角色分工 | 主代理一个人做所有事，上下文混杂 | Architect 规划、Developer 实现、Reviewer 审查，各司其职 |
| 并行探索 | 串行搜索，上下文膨胀 | 多个角色子代理并行探索不同模块 |
| 大规模分析 | 全量读入上下文 | 子代理在沙箱内分析，返回结构化摘要 |
| 隔离需求 | 主代理上下文被污染 | 每个子代理独立上下文，worktree 隔离 |
| 长期任务 | 主流程阻塞 | 后台子代理 + 通知机制 |
| 团队协作 | 单点故障，主代理卡住全卡 | 角色独立，一个失败不影响其他 |

**Cost:** Each subagent = separate API call. 2 parallel agents = ~2x tokens, but 50-70% faster completion.

## Subagent Primitives (Abstract)

### Basic Launch

```
[[AGENT:spawn description="3-5 word task" prompt="Full task instructions" background=false]]
```

### Background Launch (Non-blocking)

```
[[AGENT:spawn description="Research async patterns" prompt="Search codebase for async/await patterns..." background=true]]
// Main flow continues. Agent notifies on completion.
```

### Worktree Isolation (Independent Git Branch)

```
[[AGENT:spawn description="Implement feature branch" prompt="Implement X in isolated branch..." worktree=true]]
```

### 铁律 — Inherit Main Model

**Never specify `model` parameter. Subagent inherits main conversation's model.**

```
[[AGENT:spawn description="Architecture review" prompt="Review the architecture..."]]
[[AGENT:spawn description="Quick file search" prompt="Find all usages of..."]]
```

### Message (Continue Agent)

```
[[AGENT:message to="<agent_id>" message="New instructions..."]]
```

### Stop Agent

```
[[AGENT:stop task_id="<agent_id>"]]
```

## Available Agent Types (by Capability)

Agent types are defined by **capability**, not by CLI-specific naming. Each CLI adapter maps capabilities to its native types.

| Capability | Description | Claude Code | OpenCode | oh-my-pi | MiMo | Codex |
|---|---|---|---|---|---|---|
| **Full tools** | General research, search, multi-step, file editing | `general-purpose` | `general`, `build` | `task()` | `general` | `shell()` |
| **Read-only + planning** | Architecture design, analysis, no file mutation | `Plan` | `explore`, `scout` | read-only task | `explore` | read-only |

**铁律: Pick capability, not type name. The adapter resolves to the correct agent type.**

**See [adapters/](../adapters/) for per-CLI agent type details.**

### 铁律 — No Same-File Parallel Writes

**Multiple subagents MUST NOT modify the same file in parallel. Violation = data loss.**

```
// ❌ Wrong: two agents modify same file
[[AGENT:spawn description="Fix auth" prompt="...modify src/auth/middleware.rs..." background=true]]
[[AGENT:spawn description="Add rate limit" prompt="...modify src/auth/middleware.rs..." background=true]]

// ✅ Correct: different files -> parallel
[[AGENT:spawn description="Fix auth" prompt="...modify src/auth/middleware.rs..." background=true]]
[[AGENT:spawn description="Add rate limit" prompt="...modify src/api/rate-limit.rs..." background=true]]

// ✅ Correct: same file -> sequential
[[AGENT:spawn description="Fix auth" prompt="...modify src/auth/middleware.rs..."]]  // blocks
[[AGENT:spawn description="Add rate limit" prompt="...modify src/auth/middleware.rs..."]]  // after
```

**Execution flow (main flow responsibility):**
1. Phase 2: list target_files per REQ via `codegraph_impact` or `codegraph_context`
2. Build file allocation map — REQ-001 -> [file_a, file_b], REQ-002 -> [file_c]
3. Check file intersection — REQ-001 and REQ-003 share file_a -> no parallel
4. No intersection -> parallel | Intersection -> sequential (more files first)

## Per-Phase Subagent Patterns (角色协作)

### Phase 1: Spec Generation (Architect)

```
// Architect 主导，可派生研究子代理并行收集信息
[[AGENT:spawn description="Architect research solutions" prompt="Search for existing solutions to <feature>..." background=true]]
[[AGENT:spawn description="Architect analyze codebase" prompt="Use codegraph to map current architecture for <area>..." background=true]]
[[AGENT:spawn description="Architect edge cases" prompt="Research edge cases and failure modes for <feature>..." background=true]]
// Main flow: collect results, grill user (still needs [[USER:ask]]), write spec
```

**注意：** Grill 环节必须通过 `[[USER:ask]]` 与用户交互，Architect 子代理不能替代用户交互。

### Phase 2: Plan with Code Graph (Architect)

```
// Architect 子代理并行分析不同模块的影响范围
[[AGENT:spawn description="Analyze impact module A" prompt="Use codegraph_context to analyze module A impact..." background=true]]
[[AGENT:spawn description="Analyze impact module B" prompt="Use codegraph_context to analyze module B impact..." background=true]]
// Main flow: aggregate results, build REQ dependency graph, derive waves
```

### Phase 3: Execute (Developer x N)

```
// 波次 1: 无依赖的 REQ 并行执行
[[AGENT:spawn description="Developer REQ-001" prompt="<conductor_prompt for REQ-001>" worktree=true background=true]]
[[AGENT:spawn description="Developer REQ-003" prompt="<conductor_prompt for REQ-003>" worktree=true background=true]]
wait_for_all(wave 1)

// 波次 2: 依赖 REQ-001 的 REQ 执行（可持续 Developer 或新建）
[[AGENT:spawn description="Developer REQ-002" prompt="<conductor_prompt for REQ-002>" worktree=true background=true]]
wait_for_all(wave 2)
```

### Phase 4-7: Quality Gate (Tester + Reviewer + Simplifier)

```
// Phase 4: Tester 执行 E2E
[[AGENT:spawn description="Tester L0 happy path" prompt="Run L0 happy path tests for <feature>..." background=true]]
[[AGENT:spawn description="Tester L1 boundary" prompt="Run L1 boundary tests for <feature>..." background=true]]

// Phase 5: Reviewer 并行审查
[[AGENT:spawn description="Reviewer security" prompt="Review <files> for security vulnerabilities..." background=true]]
[[AGENT:spawn description="Reviewer architecture" prompt="Review architecture consistency for <files>..." background=true]]
[[AGENT:spawn description="Reviewer complexity" prompt="Use codegraph to analyze complexity of <files>..." background=true]]

// Phase 6: Simplifier 清理
[[AGENT:spawn description="Simplifier dead code" prompt="Find and remove dead code in <files>..." background=true]]
```

**Phase 角色顺序：** Tester -> Reviewer -> Simplifier。每个阶段等待前一阶段完成，因为 Simplifier 依赖 Reviewer 的审查意见。

## 角色交接协议 — Role Handoff Protocol

**当一个角色完成工作后，如何向下一个角色交接上下文。**

### 交接流程

```
Step 1: 完成角色输出结构化结果
[Agent Result]
REQ: REQ-001
Status: PASS
Files Modified: [file1, file2]
Tests: PASS (3/3)
Commit: abc1234
Notes: <implementation notes, design choices, gotchas>

Step 2: 主代理 (Conductor) 收集结果，更新 state.json
{
  "REQ-001": { "status": "completed", "tests": "PASS", "files": ["file1", "file2"], "commit": "abc1234" }
}

Step 3: 主代理将结果注入下一角色的 prompt
[[AGENT:message to=reviewer_id message="REQ-001 completed by Developer-1. Files: [file1, file2]. Implementation notes: <notes>. Please review for security and architecture."]]

Step 4: 接收角色确认交接
[Handoff Ack]
From: Developer-1 (REQ-001)
To: Reviewer
Context received: files, commit, notes
Review scope: confirmed
```

### 交接数据格式

每个角色完成时产出标准格式：

```
[Handoff]
From: <role_name> (REQ-xxx)
To: <next_role>
Timestamp: <iso8601>
Artifacts:
  - Files: [file1, file2]
  - Commit: <hash>
  - Branch: <branch_name>
  - Test results: <pass/fail count>
Notes:
  - Design choices: <rationale>
  - Known issues: <list>
  - Dependencies: <what other roles need to know>
  - Gotchas: <traps to avoid>
```

### 跨角色信息共享

当多个角色需要同一份上下文时，主代理通过 `[[AGENT:message]]` 广播：

```
[[AGENT:message to=reviewer_id message="Architect plan updated. New wave schedule: [...]. Target files for your review: [...]."]]
[[AGENT:message to=tester_id message="Developer completed REQ-001. Branch: feat/xxx-001. Files changed: [...]."]]
```

## Conductor Orchestration Mode

**Core pattern:** Main agent = Project Manager (Conductor), subagents = team members with roles. Each subagent has independent worktree, follows doit workflow. Main agent handles Phase 1-2, Phase 4-10. Subagents handle Phase 3 (TDD loop).

**Reference:** Open-source team workflow (Plane, GitHub PR flow). Subagent commit -> main agent review -> main agent merge.

### Conductor DO / DON'T

**Main agent (Conductor) DO:**
- Build REQ dependency graph -> derive waves
- Dispatch subagents by role (Architect, Developer, Reviewer, Tester, Simplifier)
- Poll subagent progress
- Supervise tool usage and iron rule compliance ([core/iron-rules.md](core/iron-rules.md))
- Trigger whip mechanism
- Collect all subagent results
- Verify spec alignment
- Manage role handoffs
- Deliver Review + Simplify coordination

**Main agent (Conductor) DON'T:**
- Write implementation code (Developer's job) — **Exception: Level 4 takeover**
- Modify business logic files — **Exception: Level 4 takeover**
- Do TDD loops instead of subagents — **Exception: Level 4 takeover**
- Write commits for subagents
- Skip supervision checklist

### Wave Scheduling — 波次调度器

**Phase 2: annotate dependencies per REQ:**

```
REQ-001: Create user model, dependencies: []
REQ-002: Create auth API, dependencies: [REQ-001]
REQ-003: Create user config API, dependencies: []
REQ-004: Integrate auth middleware, dependencies: [REQ-002]
```

**Wave derivation (topological sort):**

```
Wave 1: [REQ-001, REQ-003]     # No deps, parallel
Wave 2: [REQ-002]               # Depends on REQ-001
Wave 3: [REQ-004]               # Depends on REQ-002
```

**Execution template:**

```
for wave in waves:
  for req in wave:
    [[AGENT:spawn description="Developer <req.description>" prompt="<build_conductor_prompt>" worktree=true background=true]]

  wait_for_all(wave)

  for req in wave:
    result = collect_result(req)
    if not validate_result(result, req):
      handle_failure(req, result)
```

### Deep Supervision — 深度监督机制

**Checklist (after each subagent completes):**

```
[Supervision Checklist]
REQ-XXX: <description>

工具使用:
  [ ] Used codegraph_context/codegraph_search
  [ ] Used context-mode tools (ctx_search, ctx_execute)
  [ ] No forbidden tools (large shell output without compression)

TDD 循环:
  [ ] Wrote tests first (RED)
  [ ] Implementation passed tests (GREEN)
  [ ] Tests verified passing

铁律遵守:
  [ ] git commit + push completed
  [ ] MemPalace read/write (if available)
  [ ] Background execution (commands >10s)
  [ ] No files modified outside REQ scope

产出质量:
  [ ] Modified files match Phase 2 plan
  [ ] Test coverage > 0
  [ ] No compilation errors
```

**Subagent result must be structured:**

```
[Agent Result]
REQ: REQ-001
Status: PASS | FAIL | PARTIAL
Files Modified: [file1, file2]
Tests: PASS (3/3) | FAIL (1/3)
Commit: abc1234 (pushed)
Tools Used: [codegraph_context, [[FILE:edit]], [[SHELL:run]]]
Iron Rules Violated: [] | [detail]
Notes: <optional>
```

### Whip Mechanism — 鞭子机制

**四级升级:**

```
Level 1 — Progress check:
  Trigger: 50% over expected time
  Action: [[AGENT:message to=agent_id message="进度检查：你目前的进展如何？列出已完成和待完成项。"]]

Level 2 — Correction:
  Trigger: Level 1 no response or off-track
  Action: [[AGENT:message to=agent_id message="修正：你偏离了 REQ-XXX 的目标。正确做法是 [具体指令]。立即回到正轨。"]]

Level 3 — Kill and restart:
  Trigger: Level 2 no response or confirmed hang
  Action:
    1. [[AGENT:stop task_id=agent_id]]
    2. Analyze failure cause
    3. Fix prompt
    4. [[AGENT:spawn ...]] with corrected prompt

Level 4 — 主线接管 / 最终审计:
  Trigger: Level 3 restart 仍无报告，或同一 REQ 累计失败 2+ 次
  Action:
    1. [[AGENT:stop task_id=agent_id]] — 不再重启
    2. 收集主线已有证据：codegraph_context, git diff, 已提交记录, 文件状态
    3. 主代理直接完成 REQ 实现，不走子代理
    4. 生成最终审计报告：
       [Final Audit]
       REQ: REQ-XXX
       Reason: Subagent failed N times, conductor takeover
       Evidence: [codegraph results, partial commits, file state]
       Action: Conductor implemented directly
       Files: [modified files]
       Tests: [pass/fail]
       Verdict: PASS | FAIL | PARTIAL
    5. 标记该 REQ 完成，继续下一波次
  铁律：主线接管不等于跳过质量门。E2E + Review + Simplify 仍需执行。
```

### Rule Injection — 规则注入机制

**Problem:** Subagents have independent context windows. They don't inherit main conversation's SKILL.md rules.

**Solution:** Conductor prompt template MUST inject full iron rules, not summarized abstracts. Subagent prompt = subagent's SKILL.md.

**Rule injection principles:**
1. Full injection, not summary
2. Violation consequences explicit (whip mechanism trigger)
3. Self-audit mandatory before return
4. Main agent also constrained by SKILL.md
5. Role-specific rules injected based on tier (Architect gets analysis rules, Developer gets TDD rules, Reviewer gets review rules)

### Conductor Prompt Template

```
build_conductor_prompt(req, spec, context, role):
  return f"""
  ## 角色：{role}
  ## 任务：{req.description}
  ## REQ ID: {req.id}
  ## 验收标准：
  {req.acceptance_criteria}

  ## 目标文件（只修改这些文件）：
  {req.target_files}
  ## 依赖：{req.dependencies}（已完成）

  ## 上下文：
  {context}  # codegraph_context result, handoff notes from previous role

  ## ===== 铁律（必须遵守） =====

  ### 铁律 1：工具使用规范
  - MUST use codegraph_context to understand code
  - MUST use context-mode tools (ctx_search, ctx_execute)
  - MUST NOT use read-only agent types for write tasks (use Full tools)
  - MUST NOT use Bash for output >20 lines

  ### 铁律 2：TDD 循环不可跳过
  - Step 1: Write tests (RED) — tests must fail
  - Step 2: Write minimal impl (GREEN) — tests must pass
  - Step 3: Run tests — confirm passing

  ### 铁律 3：后台执行
  - >10s commands: MUST use background=true or &
  - >5min commands: MUST use tmux + Monitor

  ### 铁律 4：Commit + Push 必须完成
  - git add -> git commit -> git push
  - commit message format: type: description

  ### 铁律 5：MemPalace 读写对称
  - If MemPalace available: MUST read/write
  - If MemPalace unavailable: skip silently

  ### 铁律 6：同文件不并行
  - You own your target files
  - Don't modify files outside target list

  ### 铁律 7：文件范围不超出 REQ
  - Only modify files in target list
  - Don't add features not in spec

  ### 铁律 8：危险操作保护
  - No DROP TABLE, TRUNCATE, DELETE without WHERE
  - No rm -rf / rm -r / rm -f
  - No git push --force / git reset --hard
  - If deletion needed: confirm via [[USER:ask]]

  ## 返回格式：
  [Agent Result]
  REQ: {req.id}
  Status: PASS | FAIL | PARTIAL
  Files Modified: [...]
  Tests: PASS (X/Y) | FAIL (X/Y)
  Commit: <hash> (pushed to <branch>)
  Tools Used: [...]
  Iron Rules Violated: [] | [rule_number: detail]
  Notes: <design choices, gotchas, handoff notes for next role>
  """
```

### When NOT to Use Subagents

| Scenario | Reason | Alternative |
|----------|--------|-------------|
| Modify same file | Conflict risk | Sequential main flow |
| Need user input | Agent can't interact | Main flow + `[[USER:ask]]` |
| Simple one-line command | Agent overhead > direct exec | Direct `[[SHELL:run]]` |
| Need real-time feedback | Agent results delayed | Main flow direct exec |
| Context < 500 lines read | Agent overhead not worth it | Direct `[[FILE:read]]` |

### 自主并行 vs 团队Wave模式 — 选择指南

```
任务需要完整的 Phase 1-7 工作流？
  ├─ YES → 团队Wave模式（Architect→Developer→Reviewer）
  └─ NO → 自主并行模式
       ├─ 子任务可独立拆分？
       │   ├─ YES → 并行子代理（2-N个，background=true）
       │   └─ NO → 主代理直接执行
```

### Error Handling

```
1. Agent spawn fails -> fallback to main flow direct exec
2. Agent timeout -> check worktree state, recover partial results
3. Agent produces conflicts -> main flow merge, resolve
4. Worktree cleanup -> auto-clean after agent completes (if no changes)
5. Role agent fails -> re-spawn same role with corrected prompt (preserve context via handoff)
6. All agents in wave fail -> abort wave, analyze common cause, fix plan before retry
7. Agent fails 2+ times on same REQ -> Level 4: Conductor takeover with final audit
```
