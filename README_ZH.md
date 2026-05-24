# Do It — 做就完了

基于规格驱动、测试优先的开发工作流，专为 [Claude&nbsp;Code](https://github.com/anthropics/claude-code) 设计。自动分类需求，结合互联网搜索验证想法，强制执行规格对齐，不写测试不上线。

[English](README.md) · [简体中文](README_ZH.md)

## 目录

- [安装](#安装)
- [使用](#使用)
- [工作流程](#工作流程)
- [E2E 强制关卡](#e2e-强制关卡)
- [阶段 7: E2E 验证循环](#阶段-7-e2e-验证循环)
- [前置依赖](#前置依赖)
- [项目结构](#项目结构)

---

## 安装

```bash
# 从 GitHub 安装（替换为你的仓库）
npx skills add your-username/doit-skill

# 或本地测试
npx skills add ./path/to/doit-skill
```

## 使用

任何需求描述都会自动触发工作流：

```
> 我想要一个用户登录系统

[DOIT] 类型: F (功能) -> 完整工作流
[DOIT] 步骤 1: Tavily 搜索上下文...
[DOIT] 步骤 2: Grill 验证...
```

## 工作流程

| 阶段 | 内容 | 使用工具 |
|------|------|----------|
| -1 | 检测项目环境 | 内置 |
| 0 | 需求分类（S/F/B） | 内置 |
| 1 | 规格生成 + Grill | Tavily MCP, grill-me |
| 2 | 代码图谱规划 | tokensave |
| 3 | TDD 执行 | RTK, uv, pytest |
| 4 | 端到端测试（不可跳过） | 真实环境, HITL |
| 5 | 代码审查 + 合并 | code-review, security-review |
| 6 | 审视 + 简化（不可跳过） | 内置 |
| 7 | E2E 验证循环 | 真实环境 |
| 8 | Git 提交 | git |

### 需求类型

| 类型 | 含义 | 处理方式 |
|------|------|----------|
| **S (Simple)** | 单文件、重命名、修复 typo | 直接执行，跳过阶段 1-7 |
| **F (Feature)** | 新功能、跨模块、用户可见 | 完整阶段 1-8 |
| **B (Bug)** | 功能异常、性能回退 | Debug workflow D0-D6 |

## E2E 强制关卡

阶段 4（端到端测试）**不可跳过**。三层防御防止 Agent 跳过 E2E 直接进入审查：

1. **阶段 3 →&nbsp;4**：所有 REQ 完成后自动进入 E2E，不询问用户是否跳过。
2. **SKILL.md 关卡**：阶段 5 必须在阶段 4 产生 `e2e: passed` 后才能启动。
3. **审查预检关卡**：阶段 5 检查 `.scratch/workflow-state.json` 中的 `"e2e": "passed"` — 未通过则硬阻断。

### E2E 质量

阶段 4 **不是**"用 subprocess 写的单元测试"。它测试用户的完整旅程：

| 断言对象 | 示例 |
|---------|------|
| 退出码 | `result.returncode == 0` |
| 标准输出/错误 | `result.stdout` |
| 文件输出 | `Path("out.txt").exists()` |
| 数据库状态 | `session.query(...).one()` |

### E2E 测试层级

| 层级 | 内容 | 模式 |
|------|------|------|
| L0 | 必填参数、快乐路径 | 自动生成 |
| L1 | 边界值（空、最大值、特殊字符） | 自动生成 |
| L2 | 冲突参数组合 | HITL（人工介入） |
| L3 | 模糊/随机输入、稳定性 | HITL（人工介入） |

详见 [e2e.md](e2e.md)。

## 阶段 7: E2E 验证循环

**简化后验证，不信任。** 阶段 6（审视 + 简化）修改了代码。阶段 7 重新运行所有 e2e 测试，验证简化没有破坏用户可见的行为，然后将实际输出与 spec REQ 对比，确保输出符合用户需求。

```
阶段 6 审视+简化完成 → 运行 E2E 测试 → 通过？ → 需求对齐检查 → 符合 spec？ → 进入阶段 8 提交
                                ↓                        ↓
                               失败                   不符合：修复代码匹配 spec
```

最多 3 次循环。3 次失败后，向用户报告，建议回退阶段 6。

**Spec 是唯一真理。** 当测试输出与 spec 不一致时，修改代码而非 spec。

## 前置依赖

| 工具 | 安装 |
|------|------|
| RTK | `cargo install rtk` |
| tokensave | `cargo install tokensave` |
| Tavily MCP | 远程服务，无需安装 |

完整安装清单见 [setup.md](setup.md)。

## 项目结构

```
doit-skill/
├── SKILL.md          # 主入口
├── env-check.md      # 阶段 -1: 环境检测
├── classifier.md     # 需求类型检测
├── spec.md           # 阶段 1: Grill + REQ 生成
├── plan.md           # 阶段 2: 代码图谱扫描
├── debug.md          # 调试工作流 D0-D6 (类型 B)
├── execute.md        # 阶段 3: TDD 循环
├── e2e.md            # 阶段 4: 端到端测试 (P7 循环在 shared/e2e-verify.md)
├── review.md         # 阶段 5: 代码审查
├── review-simplify.md -> shared/   # 阶段 6: 审视 + 简化（共享）
├── commit.md -> shared/            # 阶段 8: Git 提交（共享）
├── errors.md         # 失败处理
├── shared/           # 单一真相源：Feature 和 Debug 共享的阶段
│   ├── review-simplify.md   # 审视+简化 (Feature P6, Debug D4)
│   ├── e2e-verify.md        # E2E 验证循环 (Feature P7, Debug D5)
│   └── commit.md            # Git 提交 (Feature P8, Debug D6)
├── setup.md          # 安装清单
├── package.json      # 包元数据
├── README.md         # 英文版
├── README_ZH.md      # 中文版（本文件）
└── scripts/          # 工具脚本
```
