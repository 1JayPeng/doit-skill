# Do It - 做就完了

一个命令 `/doit`，完整的 spec 驱动 + TDD 开发工作流。为 [Claude Code](https://github.com/anthropics/claude-code) 设计。

[English](README.md) - [简体中文](README_ZH.md)

## 一个命令，一切搞定

```
> /doit 我想要一个用户登录系统

[DOIT] 类型: F (功能) -> 完整工作流
[DOIT] Phase -1: 检测环境...
[DOIT] Phase 1: Grill 验证想法...
[DOIT] Phase 2: 代码图谱分析...
[DOIT] Phase 3: TDD 执行...
...
```

**不需要记多个命令。** `/doit` 自动分类需求、验证想法、写规格、规划、执行 TDD、E2E 测试、代码审查、简化、提交推送。全流程一个命令。

| 场景 | 输入 | 发生了什么 |
|------|------|-----------|
| **新功能** | `/doit 加一个搜索功能` | 完整流程：规格 -> 计划 -> TDD -> E2E -> 审查 -> 简化 -> 提交 |
| **Bug** | `/doit 登录页在空邮箱时崩溃` | 调试流程：诊断 -> 回归测试 -> 修复 -> 验证 -> 提交 |
| **简单修改** | `/doit 把配置文件改成 settings.yaml` | 直接执行，跳过流程 |
| **继续** | `/doit`（无参数） | 从上次中断处恢复 |

## 工作原理

doit 解决了一个根本问题：**AI Agent 直接写代码，不思考。** 这产生的代码看似正确，但遗漏边界情况、逻辑重复，或者没有真正解决用户描述的问题。

doit 在"用户提出"和"Agent 编码"之间插入结构化思考：

```
用户需求 -> 分类 -> 规格（Grill + REQ） -> 计划（代码图谱）
    -> 执行（TDD 逐 REQ） -> E2E（真实环境） -> 审查 -> 简化 -> E2E 验证 -> 提交
```

每个 phase 不可跳过。工作流通过质量关卡防止常见问题：

| 关卡 | 防止什么 |
|------|---------|
| 规格优先 | 建了错误的东西 |
| TDD 逐 REQ | 没有测试的代码 |
| E2E 测试 | 测试通过但功能不可用 |
| 审查 + 简化 | 重复代码、过度设计、死代码 |
| 简化后 E2E 验证 | 简化破坏已有功能 |
| 提交 + 推送 | 工作丢失 |

## 工具生态

doit 不是一个孤立的 skill，它是**工具编排器**。它整合了 9 个外部工具和 6 个内置技能，形成四层记忆架构：

```
                    /doit
                  (编排器)
                   /   |   \
                  /    |    \
                 v     v     v
           [内置技能] [外部工具] [记忆层]
```

### 内置技能（随 doit 一起安装）

| 技能 | 用途 | 使用阶段 |
|-------|---------|---------|
| `grill-me` | 想法验证 | Phase 1 |
| `tdd` | TDD 循环 | Phase 3 |
| `diagnose` | Bug 诊断 | Debug D0 |
| `prototype` | 一次性原型 | Phase 1 |
| `handoff` | 会话交接 | 任意阶段 |
| `improve-codebase-architecture` | 架构深化 | Phase 5 |

### 外部工具（setup.sh 自动安装）

| 工具 | 安装 | 使用阶段 |
|------|------|---------|
| TokenSave | `cargo install tokensave && tokensave install --agent claude` | Phase 2-7 |
| Context-Mode | `claude plugin marketplace add mksglu/context-mode` | Phase 3-7, 10 |
| AgentMemory | `claude plugin install agentmemory` | Phase -1, 0, 1, 2, 3, 5, 8, 9.5, 10 (默认) |
| MemPalace | `claude plugin install --scope user mempalace` | Phase -1, 0, 1, 2, 3, 5, 8, 9.5, 10 (备选) |
| RTK | `curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh \| sh` | 全部阶段（自动代理） |
| caveman | `claude plugin marketplace add JuliusBrussee/caveman` | Phase 0+, 10 |
| code-review | `claude plugin install code-review` | Phase 5 |
| uv | `pip install uv` | Phase 3 |
| Tavily MCP | 远程服务，只需 API key | Phase 1 |

任何工具缺失 -> 优雅降级，doit 跳过该步骤继续。

### 审查 + 简化（不可跳过）

阶段 5 审查代码：重复代码、安全漏洞（OWASP Top 10）、过度抽象、死代码。阶段 6 简化：合并重复逻辑、删除死代码、压平不必要的抽象层、减少代码行数。

**未经审查的代码不能提交。** 简化后阶段 7 重新运行所有 E2E 测试验证没有破坏功能。

### E2E 质量

阶段 4 测试用户的完整旅程 — 退出码、stdout、文件输出、数据库状态 — 不是用 `subprocess` 写的单元测试。

| 层级 | 内容 | 模式 |
|------|------|------|
| L0 | 必填参数、快乐路径 | 自动生成 |
| L1 | 边界值 | 自动生成 |
| L2 | 冲突参数组合 | HITL（人工介入） |
| L3 | 模糊/随机输入、稳定性 | HITL（人工介入） |

### 四层记忆架构

| 层级 | 工具 | 持久化范围 |
|------|------|-----------|
| 代码层 | TokenSave | 代码符号、调用关系、依赖图 — 代码变更存活 |
| 会话层 | Context-Mode | 命令输出、语义搜索索引 — 工具调用存活 |
| 跨会话层 | AgentMemory (默认) | 语义搜索、会话、治理 — 重启存活 |
| 跨会话层 | MemPalace (备选) | 规格、决策、知识图谱、agent diary — 重启存活 |

**默认: AgentMemory**（53 MCP tools, 12 hooks, 实时 viewer localhost:3113）。如果 AgentMemory 不可用则降级到 MemPalace。两者均遵循**读写对称铁律**：每个 phase 写入的数据，后续运行都会读回。Phase 0 通过 10 个并行调用重建项目上下文。

RTK 通过 PreToolUse hook 自动代理所有 Bash 命令，全阶段节省 60-90% Token。

详见 [tool-integration-guide.md](tool-integration-guide.md)。

## 工作流程

| 阶段 | 内容 | 工具 |
|------|------|------|
| -1 | 检测项目环境 | 内置, MemPalace |
| 0 | 需求分类（R/S/F/B） | 内置, caveman, MemPalace |
| 1 | 规格生成 + Grill | Tavily MCP, grill-me, MemPalace |
| 2 | 代码图谱规划 | tokensave, MemPalace |
| 3 | TDD 执行 + 审查+简化 | RTK, uv, tokensave, context-mode, MemPalace |
| 4 | 端到端测试（不可跳过） | tokensave, context-mode |
| 5 | 代码审查 | code-review, tokensave, MemPalace |
| 6 | 审视 + 简化（不可跳过） | tokensave |
| 7 | E2E 验证循环 | tokensave, context-mode |
| 8 | Git 提交 + Push | git, MemPalace |
| 9.5 | 完成总结 + 知识提取 | MemPalace |
| 10 | 自动压缩 | RTK, context-mode, MemPalace |

### E2E 验证循环

阶段 6（审视 + 简化）修改了代码。阶段 7 重新运行所有 E2E 测试，验证简化没有破坏行为，然后将实际输出与 spec REQ 对比。

```
简化完成 -> E2E 测试 -> 通过？ -> 需求对齐 -> 符合 spec？ -> 提交
                 ↓              ↓              ↓
                失败          修复代码       完成
```

最多 3 次循环。Spec 是唯一真理，不修改 spec 匹配错误输出。

### 断点续传

单次 `/doit` 调用可能无法完成整个工作流。再次输入 `/doit` 从上次中断处恢复。doit 通过对话上下文、git 状态和 spec 文件推断当前阶段。MemPalace diary 和 KG 事实提供跨会话恢复能力。

---

## 安装

### 一键安装（推荐）

```bash
curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh | bash
```

安装 doit-skill + 所有内置技能 + 所有外部工具。自动检测已安装的。

```bash
# 跳过可选工具和技能
curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh | bash -s -- --skip-optional

# 预演（显示将要安装的内容）
curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh | bash -s -- --dry-run
```

**更新：** 重新运行相同命令。

### 通过 npx

```bash
npx skills add 1JayPeng/doit-skill
```

### 本地开发

```bash
git clone https://v6.gh-proxy.org/https://github.com/1JayPeng/doit-skill.git
cd doit-skill
./scripts/setup.sh

# 验证
./scripts/doctor.sh
```

**更新：** `git pull && ./scripts/setup.sh`

## 近期更新

**2026-06-06** - AgentMemory 成为默认记忆层：
- 新默认值：AgentMemory（53 MCP tools, 12 hooks, 4 skills, 实时 viewer）
- 降级链：AgentMemory -> MemPalace -> 文件系统
- setup.sh: Step 3.5 安装 AgentMemory 插件 + 启动 memory server
- doctor.sh: 检查 AgentMemory 插件 + server 健康状态

**2026-06-04** - 工作流提升为铁律 - 任何 phase 不可跳过：
- 新增铁律："完整工作流不可跳过" - 每个 phase 必须按顺序完成
- 新增铁律："Review + Simplify 不可跳过" - 未经审查的代码不能提交
- 铁律总数：3 -> 6

**2026-06-04** - MemPalace 读写对称集成：
- 铁律："MemPalace 读写对称" - MP 调用与 tokensave 同级别，可用则必做
- Phase 0：内嵌 4 个并行 MP sweep 调用
- 各 phase 文档新增 `[MP-READ]` / `[MP-WRITE]` 标记

**2026-06-04** - 全面代码审查修复：
- 安全：修复 `scripts/add-dependency.sh` 命令注入漏洞
- Bug：修复 `env-check.md` bash 语法错误
- Bug：删除 `scripts/setup.sh` 重复的 Rust 安装代码

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
├── e2e.md            # 阶段 4: 端到端测试
├── review.md         # 阶段 5: 代码审查
├── review-simplify.md -> shared/review-simplify.md
├── commit.md -> shared/commit.md
├── errors.md         # 失败处理
├── shared/           # 共享阶段（功能 + 调试共用）
│   ├── review-simplify.md
│   ├── e2e-verify.md
│   └── commit.md
├── skills/           # 内置技能依赖
│   ├── grill-me/     # 想法验证
│   ├── tdd/          # TDD 循环
│   ├── diagnose/     # Bug 诊断
│   ├── prototype/    # 一次性原型
│   ├── handoff/      # 会话交接
│   └── improve-codebase-architecture/
└── scripts/          # 安装和工具脚本
    ├── setup.sh      # 完整安装
    ├── doctor.sh     # 依赖健康检查
    └── add-dependency.sh
```

## 添加依赖

### 添加内置技能
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
