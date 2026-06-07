# Subagent Architecture — Team Workflow Model

**核心模型：子代理 = 团队成员，主代理 = Project Manager**

参考开源团队工作流（Plane、GitHub PR 流程）。

## 架构概览

```
主代理 (Project Manager)
├── Phase 1: Spec (主代理做，需要 grill 用户)
├── Phase 2: Plan (主代理做，需要 code graph 分析)
├── Phase 3: Execute (子代理团队)
│   ├── 子代理 A: REQ-001 (worktree: feat/req-001)
│   ├── 子代理 B: REQ-002 (worktree: feat/req-002)
│   └── 子代理 C: 交叉审查 REQ-001
├── Phase 4: E2E (主代理做，需要全局视角)
├── Phase 5: Review (交叉审查子代理)
├── Phase 6: Simplify (主代理做)
├── Phase 7: E2E Verify (主代理做)
├── Phase 8: Merge + Push (主代理做)
└── Phase 9-10: Cleanup + Compact (主代理做)
```

## 为什么主代理不做实现

| 主代理做实现 | 子代理做实现 |
|------------|------------|
| 上下文膨胀（所有代码在主上下文） | 上下文隔离（代码在子代理 worktree） |
| 无法并行 | 天然并行 |
| 跳过审查（自己写自己审） | 交叉审查（A 写 B 审） |
| 质量不可控 | 监督清单 + 鞭子机制 |

## 子代理工作流规范

每个子代理遵循**适配版 doit 工作流**：

```
子代理工作流 (Per-REQ):
Phase 0: 接收任务 (REQ 描述 + 验收标准)
Phase 1: 理解代码 (tokensave_context)
Phase 2: TDD 循环
  ├── 写测试 (RED)
  ├── 实现 (GREEN)
  └── 运行测试 (验证)
Phase 3: Review + Simplify (自检)
Phase 4: Commit (git add + commit)
Phase 5: 返回结构化结果
```

**子代理不做：**
- Grill 用户（主代理的职责）
- 全局 spec 编写（主代理的职责）
- Merge 到主分支（主代理的职责）
- E2E 集成测试（主代理的职责）

## Git 工作流

### 分支策略

```
main (保护)
├── feat/feature-name (主代理分支，所有 REQ 合并目标)
│   ├── feat/req-001 (子代理 A worktree)
│   ├── feat/req-002 (子代理 B worktree)
│   └── feat/req-003 (子代理 C worktree)
```

### 子代理 Git 操作

```bash
# 子代理在 worktree 中
git checkout -b feat/req-001
# ... 实现代码 ...
git add .
git commit -m "feat: REQ-001 - <description>"
# 子代理不 push，不 merge
# 返回 commit hash 给主代理
```

### 主代理 Git 操作

```bash
# 主代理收集子代理结果后
git merge feat/req-001 --no-edit --squash
git merge feat/req-002 --no-edit --squash
# ... 所有 REQ 合并 ...
git commit -m "feat: <feature name>"
git push origin feat/feature-name
```

## 交叉审查

### 模式

```
子代理 A 实现 REQ-001
子代理 B 审查 REQ-001 (只读，不修改)
子代理 A 根据审查意见修复
主代理合并
```

### 审查子代理 Prompt

```
## 任务：审查 REQ-001 实现

## 审查清单：
1. 代码是否正确实现了 REQ 验收标准？
2. 是否有安全漏洞（OWASP Top 10）？
3. 是否有重复代码？
4. 是否有过度抽象？
5. 测试覆盖率是否足够？
6. 是否有死代码？

## 审查规则：
- 只读模式，不修改代码
- 发现问题 -> 返回审查报告
- 主代理将报告发给实现子代理修复
```

## 子代理上下文策略

### 最小必要信息

子代理 prompt 包含：

```
1. REQ 描述 (1-2 句)
2. 验收标准 (bullet points)
3. 目标文件列表 (精确路径)
4. 依赖 REQ 的完成状态
5. 代码上下文 (tokensave_context 结果)
6. 铁律 (完整注入)
7. 返回格式 (结构化结果)
```

**不包含：**
- 完整 spec 文档
- 其他 REQ 的详细信息
- 主对话历史
- 项目背景（除非必要）

### 上下文隔离的好处

| 维度 | 共享上下文 | 隔离上下文 |
|------|-----------|-----------|
| Token 消耗 | 高（所有信息重复） | 低（最小必要） |
| 干扰风险 | 高（其他 REQ 信息混淆） | 低（专注当前任务） |
| 并行安全 | 低（可能冲突） | 高（独立工作） |

## 子代理暴露进度

### 进度报告格式

```
[Progress Report]
REQ: REQ-001
Phase: TDD/GREEN/REVIEW
Progress: 75%
ETA: 2 min
Blockers: []
Files Modified: [src/file.rs]
Tests: 3/5 passing
```

### 主代理轮询

```
每 2 分钟轮询一次进度
如果 ETA 超时 -> 鞭子机制
如果 Blockers 非空 -> 主代理介入解决
```

## 主代理职责

### DO
- Phase 1: Grill 用户 + 编写 spec
- Phase 2: Code graph 分析 + 制定计划
- Phase 3: 调度子代理 + 监督 + 鞭子
- Phase 4: E2E 集成测试
- Phase 5: 协调交叉审查
- Phase 6: Simplify（全局视角）
- Phase 7: E2E 验证
- Phase 8: Merge + Push
- Phase 9-10: Cleanup + Compact

### DON'T
- 编写实现代码
- 修改业务逻辑文件
- 代替子代理做 TDD
- 跳过交叉审查

## 子代理职责

### DO
- 执行分配的 REQ
- 使用正确工具（tokensave, context-mode）
- 遵守所有铁律
- 完成后 commit（不 push，不 merge）
- 返回结构化结果

### DON'T
- 修改超出 REQ 范围的文件
- 跳过测试
- Push 到远程
- Merge 到主分支
- Grill 用户

## 工作流对比

| Phase | 单代理模式 | 子代理团队模式 |
|-------|-----------|--------------|
| Phase 1 | 主代理 grill + spec | 主代理 grill + spec |
| Phase 2 | 主代理 plan | 主代理 plan |
| Phase 3 | 主代理 TDD | 子代理 TDD + 交叉审查 |
| Phase 4 | 主代理 E2E | 主代理 E2E |
| Phase 5 | 主代理 review | 交叉审查子代理 |
| Phase 6 | 主代理 simplify | 主代理 simplify |
| Phase 7 | 主代理 verify | 主代理 verify |
| Phase 8 | 主代理 commit | 主代理 merge + push |
| Phase 9-10 | 主代理 cleanup | 主代理 cleanup |

## 配置

`.doit/config.yaml`:

```yaml
subagent:
  enabled: true
  mode: team          # team = 交叉审查 + 最小上下文
  review: cross       # cross = 交叉审查, dedicated = 专用审查子代理
  git:
    subagent_commit: true   # 子代理 commit
    main_merge: true        # 主代理 merge
    squash: true            # squash merge 保持历史整洁
```

## 与现有 Conductor 模式的兼容

现有的 Conductor Orchestration Mode 是子代理团队模式的基础。这个架构文档是扩展和细化，不是替换。

**现有保留：**
- 波次调度（Wave Scheduling）
- 鞭子机制（Whip Mechanism）
- 深度监督（Deep Supervision）
- 规则注入（Rule Injection）

**新增：**
- 交叉审查（Cross-Review）
- Git 工作流（Subagent commit + Main merge）
- 最小上下文（Minimal Context）
- 进度暴露（Progress Reporting）
- 子代理工作流规范（Per-REQ Workflow）
