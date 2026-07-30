# Do It — AI 编程 Agent 的工作流编排器

**`/doit <你想做什么>`** — 一个命令，把模糊需求变成可交付代码。

[English](README.md) · [简体中文](README_ZH.md)

## 它是什么

doit 是给 AI 编程 Agent 用的**工作流编排器**。它解决一个核心问题：AI Agent 太容易直接开始写代码。结果通常是：代码看似能跑，但漏边界、重复逻辑、没有真正解决需求。

doit 在「用户提出需求」和「Agent 编码」之间插入强制结构化流程：

```
用户 → `/doit 加登录`
        ├─ Phase 1: Grill（追问假设，澄清需求）
        ├─ Phase 2: Spec（写需求、验收标准）
        ├─ Phase 3: Plan（先设计，再动代码）
        ├─ Phase 4: TDD（测试先行，红绿重构）
        ├─ Phase 5: E2E（完整用户路径测试）
        ├─ Phase 6: Review + Simplify（安全审查、去重、删死代码）
        ├─ Phase 7: Commit（提交、推送）
        └─ 完成
```

每个 phase **不可跳过**。每个边界都有质量关卡。

## 支持平台

| 平台 | 安装 |
|------|------|
| **Claude Code** | `setup.sh --agent claude` |
| **OpenCode** | `setup.sh --agent opencode` |
| **Oh My Pi** | `setup.sh --agent omp` |
| **Codex CLI** | `setup.sh --agent codex` |
| **MCP Agent** | `setup.sh --agent mcp` |
| **手动安装** | `curl -fsSL https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh \| bash` |
| **更新** | 重新运行 `setup.sh`，自动检测并原地升级 |

## 安装指南

**一行命令。装好所有工具。**

```bash
curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh | bash
```

安装 doit-skill + 所有依赖。自动检测已安装项。再次运行即可更新。

```bash
# 跳过可选工具
curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh | bash -s -- --skip-optional

# 预演（不修改）
curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh | bash -s -- --dry-run
```

**备选安装：**

```bash
npx skills add 1JayPeng/doit-skill
```

### 验证安装

```bash
./scripts/doctor.sh
```

检查所有工具，报告缺失项，给出修复建议。

### 更新

重新运行 `setup.sh` —— 它会自动检测已有安装并原地升级。

```bash
# 从本地仓库
./scripts/setup.sh
# 或指定 agent
./scripts/setup.sh --agent claude
```

### 分发模型

- **GitHub** (`1JayPeng/doit-skill`) = 分发源
- **`~/.claude/skills/doit/`** (或 `.opencode/skills/doit/` 等) = 本地安装
- **本地开发仓库** = 开发环境 —— 推送到远程即可分发

变更流向：`本地开发 → git push → GitHub → setup.sh → ~/.claude/skills/doit/`

详见 [setup.md](setup.md)。


## 特性

### Spec 到代码的自动化流水线

7 个强制阶段：**Grill → Spec → Plan → TDD → E2E → Review → Commit**。不能跳步。每阶段必须满足关卡：验收标准明确、测试通过、审查通过，才能进入下一步。

### 多 CLI，同一套流程

同一套 `/doit` 工作流可运行在 Claude Code、OpenCode、Codex CLI、oh-my-pi、MiMo Code，以及任何支持 MCP 的 Agent。安装时自动选择工具适配器。

### 优雅降级

| 等级 | 工具缺失时 |
|------|------------|
| **关键工具**（context-mode、caveman、mempalace、headroom、codegraph） | 降级运行或显示警告 |
| **可选工具**（rtk、uv、tavily、ponytail） | 跳过对应能力，流程继续 |

没有单点硬依赖。缺一个工具，不会让整套流程瘫痪。

### 五层记忆

| 层级 | 工具 | 存什么 |
|------|------|--------|
| 会话知识库 | Context-mode | 命令输出、可搜索上下文 |
| Token 优化 | RTK | 自动压缩 Bash 命令输出，节省 60-90% token |
| 连接记忆 | Headroom | Compress-Cache-Retrieve 代理压缩 |
| 跨会话记忆 | MemPalace | 知识图谱、语义搜索、spec、决策、agent diary |
| 任务记忆 | AgentMemory | 任务进度、完成状态 |

MemPalace 提供 30 个 MCP 工具，遵循读写对称：写入过的 phase，后续运行会读回。Phase 0 通过 10 个并行调用恢复项目上下文。

### 默认懒人哲学：少写、删掉、复用

Ponytail 原则贯穿全流程：先问代码是否需要存在，优先标准库，删除死代码，压平无意义抽象。Phase 6（Review + Simplify）强制执行。

### 统一工具注册表 `tools.sh`

所有外部工具由一个可 source 的 bash 注册表管理：`scripts/tools.sh`。

它负责：

- **元数据数组**：工具 ID、显示名、关键性、fallback 策略
- **缓存 I/O**：`tools_save_status` 安装后写 JSON；`tools_read_status` 读取状态
- **显示辅助**：`_tool_emoji` 把状态映射成 emoji；`_tool_check_cached` 先读缓存，缺失再 fallback 到 `command -v`
- **doctor 集成**：`doctor.sh` 先读缓存，避免重复探测

`setup.sh` 和 `doctor.sh` 共用同一个注册表，不再复制两套工具逻辑。

## 原理

### 架构

```
GitHub 远端 ──push──→ setup.sh ──install──→ ~/.claude/skills/doit/
                         │                         │
                     tools.sh                  doctor.sh
                         │                         │
              ┌──────────┴──────────┐       cache-first 检查
              ▼                     ▼             │
        每工具安装脚本          缓存 I/O      tools_read_status
        scripts/installers/     env-cache.json     │
                                                    ▼
                                             缺缓存时 fallback
                                             到 command -v
```

变更流向：**本地开发 → git push → GitHub → setup.sh → ~/.claude/skills/doit/**。

### Phase 明细

| # | Phase | 内容 | 工具 | 关卡 |
|---|-------|------|------|------|
| 0 | Context sweep | 从记忆恢复项目状态 | MemPalace, codegraph | 10 个并行调用完成 |
| 1 | Grill | 追问假设，澄清需求 | deep-grill, Tavily, MemPalace | spec 无歧义 |
| 2 | Spec | 写需求和验收标准 | MemPalace | AC 可测试 |
| 3 | Plan | 先设计，再写代码 | codegraph | plan 已审查 |
| 4 | TDD | 测试先行，红绿重构 | RTK, Headroom | 测试通过 |
| 5 | E2E | 完整用户路径测试 | — | E2E 通过 |
| 6 | Review + Simplify | OWASP、去重、删死代码 | code-review, Ponytail | 无开放发现 |
| 7 | Commit | commit message、push | caveman | 已推送 |

### E2E 验证循环

Phase 6 会改代码。Phase 7 重新跑所有 E2E，确认简化没有破坏行为，再把实际输出和 spec REQ 对比。**修代码，不改 spec 去适配错误输出。** 最多 3 次循环，仍失败则升级给用户。

## 内置技能

| 技能 | 用途 | 阶段 |
|------|------|------|
| `.iron-rules` | 强制工作流规则 | 全阶段 |
| `caveman` | 极简表达、commit message | Phase 7 |
| `code-review` | 安全、架构、重复逻辑审查 | Phase 6 |
| `context-mode` | 可搜索会话知识库 | Phase 0，全 ctx_* 调用 |
| `deep-grill` | 4 阶段苏格拉底/第一性原理追问引擎 | Phase 1（主） |
| `deep-grill-cn` | deep-grill 中文版 | Phase 1（中文用户） |
| `grill-me` | Type B/S 任务简版问答 | Phase 1（fallback） |
| `mempalace` | 跨会话语义记忆 | Phase 0, 1, 2, 7 |
| `ponytail` | YAGNI 简化 | Phase 6 |

## 外部工具

`setup.sh` 自动安装。缺失时优雅降级。

| 工具 | 作用 | 安装 | Fallback |
|------|------|------|----------|
| [Context-Mode](https://github.com/mksglu/context-mode) | 上下文窗口管理 | `npm install -g context-mode` | degraded |
| [RTK](https://github.com/rtk-ai/rtk) | Token 优化 CLI 代理 | `npm install -g rtk` | skip |
| [Headroom](https://github.com/headroomlabs-ai/headroom) | 代理压缩 + 记忆 | `npm install -g headroom` | skip |
| [MemPalace](https://github.com/MemPalace/mempalace) | 跨会话语义记忆 | `uv tool install mempalace` | degraded |
| [Caveman](https://github.com/JuliusBrussee/caveman) | 极简表达模式 | 内置 skill | skip |
| Code Review | OWASP 安全审查 | 内置 skill | skip |
| [Tavily MCP](https://tavily.com) | 规格阶段联网研究 | `pip install tavily-mcp` | skip |
| [uv](https://github.com/astral-sh/uv) | 快速 Python 包管理器 | `curl -LsSf https://astral.sh/uv/install.sh \| sh` | degraded |
| [CodeGraph](https://github.com/colbymchenry/codegraph) | AST 符号查询、调用图、影响分析 | `npm install -g @codegraph/codegraph` | degraded |
| Ponytail | YAGNI 简化 | 内置 skill | skip |

## 四个核心原则

| 原则 | 防止什么 | 用在哪里 |
|------|----------|----------|
| **先想清楚再写代码** | 需求没搞清就开写 | Grill、Spec、Plan |
| **测试保护行为** | 回归、假阳性信心 | TDD、E2E、最终复验 |
| **删除优先于新增** | 膨胀、死代码、无意义抽象 | Review + Simplify, Ponytail |
| **优雅降级** | 工具链脆弱、安装失败 | tools.sh criticality/fallback |

## 项目结构

```
doit-skill/
├── scripts/
│   ├── setup.sh                # 安装器：自动检测 CLI、安装工具、写缓存
│   ├── doctor.sh               # 诊断器：cache-first 检查、按 agent 报告
│   ├── tools.sh                # 注册表：元数据、缓存 I/O、显示 helper
│   ├── setup.ps1 / doctor.ps1  # Windows PowerShell 版本
│   └── installers/             # 每个工具一个安装脚本
├── .omp/
│   └── skills/doit/scripts/    # 运行时副本
├── core/
│   └── env-check.md            # doctor 文档 + cache I/O 说明
├── skills/                     # 内置 skills
│   ├── caveman/
│   ├── code-review/
│   ├── context-mode/
│   ├── mempalace/
│   └── ponytail/
├── setup.md                    # 完整安装文档
└── README.md / README_ZH.md
```

## 断点续跑

一次 `/doit` 不一定跑完整流程。再次输入 `/doit`，它会根据对话上下文、git 状态、spec 文件判断当前 phase。MemPalace diary 和 KG 事实用于跨会话恢复。

## 添加工具

### 添加外部工具

1. 创建 `scripts/installers/install_<tool>.sh`，包含 `install_<t>()`、`verify_<t>()`、`version_<t>()`
2. 在 `scripts/tools.sh` 注册：`ALL_TOOLS`、`TOOL_NAMES`、criticality、fallback
3. `doctor.sh` 会自动通过注册表循环使用它

### 添加内置技能

```bash
./scripts/setup.sh --add-skill <name> --repo <url>
```
