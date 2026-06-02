# Do It — 做就完了

基于规格驱动、测试优先的开发工作流，专为 [Claude&nbsp;Code](https://github.com/anthropics/claude-code) 设计。自动分类需求，结合互联网搜索验证想法，强制执行规格对齐，不写测试不上线。

[English](README.md) · [简体中文](README_ZH.md)

## 特性

- **自动分类** — 区分简单修复、功能需求和 bug。简单变更直接上线；功能需求走完整流程。
- **规格优先** — 结合互联网研究验证想法，生成验收标准（REQ-001, REQ-002...）。规格确认前不写代码。
- **TDD 强制执行** — 每个验收标准经过 RED → GREEN → REFACTOR。没有失败测试不写实现。
- **E2E 关卡** — 真实环境端到端测试。不可跳过，不可绕过。
- **审查 + 简化** — 每次变更必须通过审查，去除重复代码、死代码和过度设计。保持代码精简。
- **Git 提交** — Phase 8 使用有意义的提交信息，更新规格状态。功能分支准备就绪。
- **断点续传** — 工作流程跨越多次对话。再次输入 `/doit` 从上次中断处恢复。
- **全面环境检测** — Phase -1 扫描所有虚拟环境类型 (conda/uv/venv/poetry/asdf/mise/nvm/...)、版本文件 (.python-version/.node-version/.tool-versions/...)、锁定文件 (uv.lock/poetry.lock/package-lock.json/...)、Docker/K8s 和系统信息。24h 缓存，多环境冲突检测。写入 CLAUDE.md 确保后续会话正确启动。

## 工作原理

doit 解决了一个根本问题：**AI Agent 直接写代码，不思考。** 这产生的代码看似正确，但遗漏边界情况、逻辑重复，或者没有真正解决用户描述的问题。

doit 在"用户提出"和"Agent 编码"之间插入结构化思考：

```
用户需求 → 环境检测 → 分类 → 规格（Grill + REQ） → 计划（代码图谱）
       → 执行（TDD 逐 REQ） → E2E（真实环境） → 审查 → 简化 → E2E 验证 → 提交
```

**Phase -1** — 检测项目环境。什么语言、什么包管理器、什么虚拟环境。缺失则写入 CLAUDE.md。无法确定 → 询问用户。

**Phase 0** — 分类需求。简单变更？跳过流程，直接做。功能？完整流程。Bug？Debug 工作流（D0-D6）。

**Phase 1** — 验证想法。搜索已有解决方案。挑战假设。生成可测试的验收标准。

**Phase 2** — 扫描代码库。哪些代码受影响？社区和符号级别的冲击是什么？

**Phase 3** — 逐个 REQ 实现。测试 → 代码 → 重构。每个 REQ 完成后审查和简化。

**Phase 4** — 真实环境端到端测试。不是用 `subprocess` 写的单元测试。对退出码、stdout、文件输出、数据库状态的断言。

**Phase 5-6** — 功能级代码审查（OWASP 安全、架构）。然后简化 — 去除重复代码，压平抽象。

**Phase 7** — E2E 验证循环。简化后重新运行所有 e2e 测试，然后与实际输出对比 spec REQ。输出不匹配则修复代码。循环直到 e2e 通过且输出匹配规格。

**Phase 8** — Git 提交，附带有意义的信息。功能分支准备合并。

## 目录

- [特性](#特性)
- [工作原理](#工作原理)
- [安装](#安装)
  - [一键安装（推荐）](#一键安装推荐)
  - [通过 npx](#通过-npx)
  - [本地开发](#本地开发)
  - [Doctor](#doctor)
- [使用](#使用)
- [工作流程](#工作流程)
- [E2E 强制关卡](#e2e-强制关卡)
- [阶段 7: E2E 验证循环](#阶段-7-e2e-验证循环)
- [前置依赖](#前置依赖)
- [工具集成指南](#工具集成指南)
- [项目结构](#项目结构)
- [添加依赖](#添加依赖)

---

## 安装

### 一键安装（推荐）

```bash
curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh | bash
```

安装 doit-skill 及所有依赖。自动检测已安装的工具。

```bash
# 跳过可选技能和外部工具
curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh | bash -s -- --skip-optional

# 预演（显示将要安装的内容）
curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh | bash -s -- --dry-run
```

**更新：** 重新运行相同命令即可。

### 通过 npx

```bash
npx skills add 1JayPeng/doit-skill
```

**更新：** npx skills 会提示更新。

### 本地开发

```bash
# 克隆并安装
git clone https://v6.gh-proxy.org/https://github.com/1JayPeng/doit-skill.git
cd doit-skill
./scripts/setup.sh

# 预演（安装前预览）
./scripts/setup.sh --dry-run

# 验证
./scripts/doctor.sh
```

**更新：** `git pull && ./scripts/setup.sh`

### Doctor

检查所有依赖（安装或更新后）：

```bash
./scripts/doctor.sh
```

---

## 使用

任何需求描述都会自动触发工作流：

```
> 我想要一个用户登录系统

[DOIT] 类型: F (功能) -> 完整工作流
[DOIT] 步骤 1: Tavily 搜索上下文...
[DOIT] 步骤 2: Grill 验证...
```

### 继续工作流

单次 `/doit` 调用可能无法完成整个工作流 — 规格验证、实现、测试和审查是一个漫长的过程。要从中断处恢复，在当前对话中再次输入 `/doit` 即可。工作流程从当前阶段继续（通过对话上下文和 git/spec 文件状态推断）。

```
> /doit

[DOIT] 从 Phase 4 (E2E) 恢复 — Phase 3 已完成
[DOIT] 运行 E2E 测试...
```

## 工作流程

| 阶段 | 内容 | 使用工具 |
|------|------|----------|
| -1 | 检测项目环境 | 内置, mempalace |
| 0 | 需求分类（R/S/F/B） | 内置, caveman, mempalace |
| 1 | 规格生成 + Grill | Tavily MCP, grill-me, mempalace |
| 2 | 代码图谱规划 | tokensave, mempalace |
| 3 | TDD 执行 + 审查+简化 | RTK, uv, tokensave, context-mode, mempalace |
| 4 | 端到端测试（不可跳过） | tokensave, context-mode |
| 5 | 代码审查 + 合并 | code-review, tokensave, mempalace |
| 6 | 审视 + 简化（不可跳过） | tokensave |
| 7 | E2E 验证循环 | tokensave, context-mode |
| 8 | Git 提交 + Push | git, mempalace |
| 9.5 | 完成总结 | mempalace |
| 10 | 自动压缩 | RTK, context-mode, mempalace |

## E2E 强制关卡

阶段 4（端到端测试）**不可跳过**。三层防御防止 Agent 跳过 E2E 直接进入审查：

1. **阶段 3 →&nbsp;4**：所有 REQ 完成后自动进入 E2E，不询问用户是否跳过。
2. **SKILL.md 关卡**：阶段 5 必须在阶段 4 产生 `e2e: passed` 后才能启动。
3. **审查预检关卡**：阶段 5 必须确认所有 L0+L1 E2E 测试通过才能启动 — 未通过则硬阻断。

### E2E 质量

阶段 4 **不是**"用 subprocess 写的单元测试"。它测试用户的完整旅程：

| 断言对象 | 示例 |
|---------|---------|
| 退出码 | `result.returncode == 0` |
| 标准输出/错误 | `result.stdout` |
| 文件输出 | `Path("out.txt").exists()` |
| 数据库状态 | `session.query(...).one()` |

E2E 测试层级：

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
                                    ↓                        ↓                         ↓
                                   失败                   不符合：修复代码
                                                          匹配规格
```

最多 3 次循环。3 次失败后，向用户报告，建议回退阶段 6。

**Spec 是唯一真理。** 当测试输出与 spec 不一致时，修改代码而非修改 spec。

## 前置依赖

doit 使用**捆绑依赖模型** — 核心技能内置在 `skills/` 目录中。外部工具需要单独安装。

### 捆绑技能（随 doit 一起安装）

| 技能 | 用途 | 使用阶段 |
|-------|---------|---------|
| `grill-me` | 想法验证 | Phase 1 |
| `tdd` | TDD 循环 | Phase 3 |
| `diagnose` | Bug 诊断 | Debug workflow D0 |
| `prototype` | 一次性原型 | Phase 1（设计探索）|
| `handoff` | 会话交接 | 任意阶段 |
| `improve-codebase-architecture` | 架构深化 | Phase 5 |

### 外部工具（用户安装）

| 工具 | 安装 | 使用阶段 |
|------|---------|---------|
| Context-Mode | `claude plugin marketplace add mksglu/context-mode` | Phase 3-7, 10 |
| RTK | `curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh \| sh` | 全部阶段（自动代理） |
| uv | `pip install uv` | Phase 3 |
| Rust | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh` | tokensave 前置依赖 |
| tokensave | `cargo install tokensave && tokensave install --agent claude` | Phase 2-7 |
| MemPalace | `claude plugin install --scope user mempalace` | Phase -1, 0, 1, 2, 3, 5, 8, 9.5, 10 |
| caveman | `claude plugin marketplace add JuliusBrussee/caveman && claude plugin install caveman@caveman` (curl fallback) | Phase 0+ |
| code-review | `claude plugin install code-review` | Phase 5 |
| Tavily MCP | 远程服务，只需 API key | Phase 1 |

## 工具集成指南

doit 在整个工作流程中集成了 **8 个外部工具**，形成了三层记忆架构。每个阶段具体调用哪些工具、执行什么命令、设计取舍是什么 — 详见 [tool-integration-guide.md](tool-integration-guide.md)。

**三层记忆架构：**
- **TokenSave** — 代码图谱（符号、调用关系、依赖）
- **Context-Mode** — 会话级上下文（命令输出索引、语义搜索）
- **MemPalace** — 跨会话语义记忆（规格、决策、实现笔记）

**Token 优化：** RTK 通过 PreToolUse hook 自动代理所有 Bash 命令，全阶段节省 60-90% Token。

## 项目结构

```
doit-skill/
├── SKILL.md          # 主入口
├── env-check.md      # 阶段 -1: 环境检测
├── classifier.md     # 需求类型检测
├── doc-capture.md    # 文档捕获（预阶段）
├── doit-config.md    # 配置参考
├── spec.md           # 阶段 1: Grill + REQ 生成
├── plan.md           # 阶段 2: 代码图谱扫描
├── debug.md          # 调试工作流 D0-D6 (类型 B)
├── execute.md        # 阶段 3: TDD 循环 + 审查+简化
├── e2e.md            # 阶段 4: 端到端测试 (P7 循环在 shared/e2e-verify.md)
├── review.md         # 阶段 5: 代码审查
├── review-simplify.md -> shared/review-simplify.md # 阶段 6: 审视 + 简化（共享）
├── commit.md -> shared/commit.md        # 阶段 8: Git 提交（与 debug D6 共享）
├── errors.md         # 失败处理
├── shared/           # 单一真相源：Feature 和 Debug 共享的阶段
│   ├── review-simplify.md   # 审视+简化 (Feature P6, Debug D4)
│   ├── e2e-verify.md        # E2E 验证循环 (Feature P7, Debug D5)
│   └── commit.md            # Git 提交 (Feature P8, Debug D6)
├── setup.md          # 安装清单
├── tool-integration-guide.md  # 各阶段外部工具使用指南
├── mempalace.md      # MemPalace 跨阶段集成
├── background-process.md      # 后台进程日志模式
├── package.json      # 包元数据 + 依赖
├── README.md         # 英文版
├── README_ZH.md      # 中文版（本文件）
├── skills/           # 捆绑技能依赖
└── scripts/          # 安装和工具脚本
    ├── setup.sh      # 完整安装脚本 (curl 或本地)
    ├── doctor.sh     # 依赖健康检查
    └── add-dependency.sh # 添加新技能依赖
```

## 添加依赖

### 添加捆绑技能
```bash
./scripts/add-dependency.sh <skill-name> bundled
```

### 添加可选技能
```bash
# 编辑 package.json
"dependencies.optionalSkills": {
  "new-skill": "recommended"
}
```

### 添加外部工具
```bash
# 编辑 package.json
"dependencies.tools": {
  "new-tool": "install-command"
}
```
