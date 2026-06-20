# Team Roles — Subagent Team Definition
**Supplement to [subagent.md](subagent.md). Defines roles, handoff protocol, and lifecycle for multi-agent teams.**

## Role Directory

| Role | Agent Type | Phase | Lifecycle | Count |
|------|-----------|-------|-----------|-------|
| **Conductor** | Main agent | 0-10 | 全程驻留 | 1 |
| **Researcher** | `general-purpose` | 1 | 波次 | 1-3 |
| **Architect** | `Plan` | 1-2 | 波次 | 1 |
| **Developer** | `general-purpose` | 3 | 持续 | N (动态) |
| **Tester** | `general-purpose` | 4-7 | 持续 | 1 |
| **Reviewer** | `Plan` | 5-6 | 持续 | 1 |

**波次角色**: Phase 完成即释放，不跨波次保留。
**持续角色**: 在指定 Phase 范围内全程驻留，可跨波次接收任务。

---

## 1. Conductor (主代理)

**Lifecycle:** 全程驻留，Phase 0-10 不释放。

| 属性 | 值 |
|------|-----|
| 职责 | 编排所有子代理、波次调度、深度监督、交接包验证 |
| 工具 | 全部工具 + `[[AGENT:spawn]]`, `[[AGENT:msg]]`, `[[AGENT:stop]]` |
| 产出 | 波次计划、交接包、决策记录 |

**DO:**
- Build REQ dep graph, derive waves (topological sort)
- Dispatch subagents per wave, one per independent REQ
- Poll progress, trigger whip mechanism
- Validate handoff packages from each role
- Deliver Review + Simplify (Phase 5-6)
- Collect results, verify spec alignment

**DON'T:**
- Write impl code directly
- Do TDD loops instead of Developers
- Skip handoff validation
- Parallel-write the same file from multiple agents

---

## 2. Researcher (调研员)

| 属性 | 值 |
|------|-----|
| 阶段 | Phase 1 |
| Agent type | `general-purpose` |
| Lifecycle | 波次 — Phase 1 完成即释放 |
| 数量 | 1-3（按研究维度拆分） |

**职责:**
- Web 研究：现有技术选型、竞品分析、最佳实践
- 文档收集：API 文档、库参考、框架指南
- 边界情况发现：edge cases、失败模式、已知坑
- 用户需求分析：从模糊需求中提取可执行 REQ

**工具:**
- `tavily_search`, `tavily_research`: 联网搜索
- `ctx_fetch_and_index`: 网页内容索引
- `WebFetch`: 单页抓取

**产出:**
- 调研报告：`.spec/research.md`
- 竞品分析：`.spec/competitive-analysis.md`
- 技术选型建议：`.spec/tech-decisions.md`
- 边界情况列表：`.spec/edge-cases.md`

**交接包:**
```
[Handoff Package]
Role: Researcher
Phase: 1
Status: COMPLETE | PARTIAL | BLOCKED
Artifacts: [.spec/research.md, .spec/tech-decisions.md]
Decisions: [技术选型 A 选 X 库，理由 Y]
Blockers: [API 文档缺失，需用户确认]
Next Role: Architect
Notes: <上下文补充>
```

---

## 3. Architect (架构师)

| 属性 | 值 |
|------|-----|
| 阶段 | Phase 1-2 |
| Agent type | `Plan` |
| Lifecycle | 波次 — Phase 2 完成即释放 |
| 数量 | 1 |

**职责:**
- 代码图谱分析：`codegraph_context`, `tokensave_context`
- 影响范围评估：`codegraph_impact`, `tokensave_impact`
- REQ 依赖图构建：拓扑排序，导出波次
- 执行顺序制定：文件分配表，避免同文件并行写入
- 执行计划输出：`.spec/plan.md`

**工具:**
- `codegraph_*`: 代码图谱查询
- `tokensave_*`: 代码图谱备用查询
- `ctx_*`: lean-ctx 工具链

**产出:**
- 影响分析报告：`.spec/impact.md`
- REQ 依赖图：`.spec/dep-graph.md`
- 执行顺序：`.spec/exec-order.md`
- 文件分配表：`.spec/file-alloc.md`

**交接包:**
```
[Handoff Package]
Role: Architect
Phase: 2
Status: COMPLETE | PARTIAL | BLOCKED
Artifacts: [.spec/impact.md, .spec/dep-graph.md, .spec/exec-order.md, .spec/file-alloc.md]
Decisions: [REQ-001 和 REQ-003 无文件交集，可并行]
Blockers: [无]
Next Role: Developer (Wave 1)
Notes: <波次调度表 + 文件分配>
```

---

## 4. Developer (开发者)

| 属性 | 值 |
|------|-----|
| 阶段 | Phase 3 |
| Agent type | `general-purpose` |
| Lifecycle | 持续 — Phase 3 全程驻留 |
| 数量 | N（按独立 REQ 数动态决定） |

**职责:**
- TDD 循环：RED (写测试) → GREEN (最小实现) → REFACTOR (重构)
- 按 REQ 独立开发，不跨 REQ 边界
- 每个 Developer 拥有独立 worktree，互不干扰
- 完成后 git commit + push 到独立分支

**工具:**
- `codegraph_*`: 代码理解
- `ctx_*`: 命令执行、搜索
- `Edit`, `Write`: 文件修改
- `Bash`: 测试命令（仅限短输出）

**约束:**
- **同文件不并行**: 文件分配表已由 Architect 生成，严格遵守
- **TDD 不可跳过**: 必须先有 RED 失败测试，再 GREEN 通过
- **工作树隔离**: 每个 Developer 在独立 worktree 中工作
- **文件范围**: 只修改目标文件列表中的文件

**Developer 波次执行:**
```
Wave 1: [REQ-001, REQ-003]     # 无依赖，并行
  [[AGENT:spawn desc="REQ-001: ..." worktree=true background=true]]
  [[AGENT:spawn desc="REQ-003: ..." worktree=true background=true]]
  wait_for_all(Wave 1)
  collect_results()

Wave 2: [REQ-002]               # 依赖 REQ-001
  [[AGENT:spawn desc="REQ-002: ..." worktree=true background=true]]
  wait_for_all(Wave 2)
  collect_results()
```

**交接包:**
```
[Handoff Package]
Role: Developer
Phase: 3
Status: COMPLETE | PARTIAL | BLOCKED
REQ: REQ-001
Artifacts: [src/impl.rs, tests/impl_test.rs]
Decisions: [使用 HashMap 而非 BTreeMap，性能优先]
Blockers: [无]
Next Role: Tester
Notes: <branch: feat/req-001, commit: abc1234>
```

---

## 5. Tester (测试员)

| 属性 | 值 |
|------|-----|
| 阶段 | Phase 4-7 |
| Agent type | `general-purpose` |
| Lifecycle | 持续 — Phase 4-7 全程驻留 |
| 数量 | 1 |

**职责:**
- E2E 测试分级执行：
  - **L0 快乐路径**: 核心功能正常流程
  - **L1 边界条件**: 空输入、最大值、特殊字符
  - **L2 异常处理**: 网络失败、权限错误、数据冲突
  - **L3 性能**: 大输入、并发、超时
- 回归测试：每次 Review 后重新验证
- 覆盖率报告：测试覆盖率数据

**工具:**
- `Bash`: 测试运行器
- `ctx_shell`: 压缩输出
- `ctx_execute`: 测试分析脚本

**产出:**
- 测试报告：`.spec/test-report.md`
- 覆盖率数据：`.spec/coverage.md`
- 回归验证结果：`.spec/regression.md`

**交接包:**
```
[Handoff Package]
Role: Tester
Phase: 4
Status: COMPLETE | PARTIAL | BLOCKED
Artifacts: [.spec/test-report.md, .spec/coverage.md]
Decisions: [L2 异常场景跳过，需用户确认错误码]
Blockers: [REQ-002 L1 测试 FAIL，需 Developer 修复]
Next Role: Reviewer
Notes: <L0 全通过, L1 3/4 通过, L2 待确认>
```

---

## 6. Reviewer (审查员)

| 属性 | 值 |
|------|-----|
| 阶段 | Phase 5-6 |
| Agent type | `Plan` |
| Lifecycle | 持续 — Phase 5-6 全程驻留 |
| 数量 | 1 |

**职责:**
- 代码审查：API 一致性、错误处理、资源清理
- 重复代码检测：提取公共函数、消除冗余
- 过度工程识别：简化不必要的抽象层
- 简化建议：提供具体可执行的简化清单
- 安全审查：敏感数据、注入漏洞、权限控制

**工具:**
- `codegraph_*`: 结构分析
- `tokensave_*`: 代码查询
- `ctx_search`: 模式搜索
- `ctx_read`: 文件内容

**产出:**
- 审查报告：`.spec/review-report.md`
- 简化清单：`.spec/simplify-todos.md`
- 安全审查：`.spec/security-report.md`（如适用）

**交接包:**
```
[Handoff Package]
Role: Reviewer
Phase: 6
Status: COMPLETE | PARTIAL | BLOCKED
Artifacts: [.spec/review-report.md, .spec/simplify-todos.md]
Decisions: [移除 Middleware 抽象，直接在 handler 中处理]
Blockers: [无]
Next Role: Tester (回归验证)
Notes: <简化 3 处重复代码, 移除 1 层抽象>
```

---

## Handoff Protocol (交接协议)

**每个角色完成工作后，必须产出结构化交接包。** 交接包格式见上方各角色定义。

### 交接包字段说明

| 字段 | 必填 | 说明 |
|------|------|------|
| `Role` | Y | 角色名 |
| `Phase` | Y | 当前阶段 |
| `Status` | Y | `COMPLETE` / `PARTIAL` / `BLOCKED` |
| `Artifacts` | Y | 产出文件列表 |
| `Decisions` | Y | 关键决策列表 |
| `Blockers` | Y | 阻塞问题（若无则填 `[无]`） |
| `Next Role` | Y | 交接给哪个角色 |
| `Notes` | N | 补充上下文 |

### 交接流程

```
Researcher ──handoff──> Architect ──handoff──> Developer (Wave N)
                                                              │
                                                              ▼
                                                         Tester ──handoff──> Reviewer
                                                              │                  │
                                                              └──────handoff─────┘
                                                                   (回归)
```

**Conductor 验证规则:**
1. 检查 `Status` 字段 — `BLOCKED` 需要人工介入
2. 验证 `Artifacts` 文件存在且非空
3. 确认 `Next Role` 与波次计划一致
4. `PARTIAL` 状态需要 Conductor 决定是否继续

---

## Role Lifecycle (角色生命周期)

### 波次角色 (Burst)
```
Phase start → [[AGENT:spawn]] → 执行任务 → 产出交接包 → 释放
```
- Researcher, Architect 属于波次角色
- Phase 完成后立即释放，不保留上下文
- 适合一次性任务：调研、规划、分析

### 持续角色 (Persistent)
```
Phase start → [[AGENT:spawn]] → 接收任务 → 执行 → 等待下一任务 → ... → Phase end → 释放
```
- Developer, Tester, Reviewer 属于持续角色
- 在指定 Phase 范围内持续驻留
- 通过 `[[AGENT:msg]]` 接收新任务
- 适合迭代式工作：TDD、测试、审查

### Conductor (全程)
```
Session start → 编排所有 Phase → Session end → [[MEMORY:compress]]
```
- 全程驻留，负责所有波次的调度
- 不释放，直到 Phase 10 完成

---

## Role Selection Guide (角色选择指南)

| 场景 | 推荐角色 | 原因 |
|------|---------|------|
| 需要联网搜索 | Researcher | `general-purpose` + web 工具 |
| 需要代码分析 | Architect | `Plan` + codegraph |
| 需要写代码 | Developer | `general-purpose` + Edit/Write |
| 需要跑测试 | Tester | `general-purpose` + shell |
| 需要审代码 | Reviewer | `Plan` + read-only 工具 |
| 简单查询 | 主代理直执行 | 子代理开销不值得 |
| 单文件修改 | 主代理直执行 | 无需隔离 |
