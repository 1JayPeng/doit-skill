# Iron Rules — 铁律详情

**本文件包含铁律的完整规则。SKILL.md 仅保留摘要。执行对应 phase 前，必须读取相关铁律。**

## 铁律 — Non-Interruptive Questions

**永远不要停止对话来问用户问题。始终使用 AskUserQuestion 工具。**

旧模式：打印问题 -> 停止 -> 等用户输入。这阻塞工作流、浪费 token、让用户烦躁。
新模式：调用 `AskUserQuestion`，用户无需中断即可回答。Agent 继续执行。

- 绝不写"你选哪个？"然后停下来等
- 绝不写"Wait for user input"然后暂停
- 始终用 `AskUserQuestion` + 2-4 个选项
- 始终提供合理默认值作为第一个选项
- 用户不回答 -> 用推荐默认值继续，不阻塞工作流
- **grill 问题同样适用。** 5+(Type F)/3+(Type B) 个 grill 问题必须通过 AskUserQuestion 发出，用户不回答则用推荐默认值继续。跳过 grill 问题 ≠ 用户不回答。

### Applied Everywhere

- **Phase -1 (Env Detection)** — env conflict -> AskUserQuestion with detected envs as options
- **Phase 1 (Spec)** — grill -> AskUserQuestion for each clarification
- **Phase 3 (Execute)** — spec alignment -> AskUserQuestion "Proceed to next REQ?"
- **Phase 4 (E2E)** — L2/L3 HITL -> AskUserQuestion "Which combo needs testing?"
- **Debug (D0)** — reproduction steps unclear -> AskUserQuestion

## 铁律 — Background Execution

**永远不要空等长时间任务。始终使用 tmux + 实时日志 + 自动轮询。这是铁律，不是建议。**

旧模式：运行 `cargo build --release` -> 干等 5min -> 结果。这阻塞工作流、浪费 token、让用户盯着冻结的 agent。
新模式：tmux 命名 session 启动 -> 日志实时写入 log 文件 -> `/loop` 自动轮询 `[END]` 标记 -> 完成后自动继续下一 phase。

### 决策门控（每个命令运行前必须执行）

在运行任何 Bash 命令前，**必须**先判断：

1. **这个命令预计需要多长时间？**
2. **>10s？** → 禁止前台直接运行，必须 tmux + 实时日志 + `/loop` 轮询
3. **后台任务设置完成后，是否已设置完成信号（`[END]` 标记 + `/loop`）？** → 没有则禁止继续

### 统一执行标准

- **<10s** → 直接 Bash（前台 OK）
- **>10s** → **tmux 命名 session + 实时日志 + `/loop` 自动轮询**

**所有长任务统一使用 tmux。** 不用 shell `&`，不用 `run_in_background`。Tmux 是唯一标准。

### 为什么是 tmux（不是 shell &）

| 特性 | tmux | shell & |
|------|------|---------|
| 实时日志 | log 文件持续写入，随时 `tail` 可读 | 输出缓冲，日志可能延迟 |
| 进程管理 | 独立 session，可 attach 查看 | 依赖 shell 进程组 |
| 崩溃恢复 | session 持久，可重新连接 | shell 退出进程丢失 |
| 多阶段 pipeline | split-window 多 pane 协同 | 需要手动编排 |
| 完成检测 | `[END]` 标记写入 log，`/loop` 轮询 | 需要 wait + trap |

### 强制轮询规则

**每个后台任务必须有 tmux session + `/loop` 轮询。没有轮询的后台任务 = 丢失的工作。**

1. **启动 tmux session** — 命名 `doit-<phase>`，写入 `.scratch/logs/<name>.log`
2. **日志必须包含 `[START]` 和 `[END]` 标记** — `[END]` 包含 exit_code
3. **设置 `/loop` 轮询** — 检查 `[END]` 标记，完成后读取结果并报告
4. **压缩上下文** — 调用 `headroom_compress` 压缩当前上下文，避免轮询期间上下文膨胀
5. **轮询期间做其他工作** — 不空等

### 禁止行为

- **禁止**运行长时间命令后停止响应、沉默等待
- **禁止**前台运行 >10s 的命令后干等
- **禁止**用 shell `&` 代替 tmux — tmux 是唯一标准
- **禁止**忘记设置完成信号（`[END]` 标记 + `/loop` 轮询）
- **禁止**对后台任务不设 timeout（默认 300s）
- **禁止**在长对话中忘记后台任务的存在 → 用户问进度时立即检查 `.scratch/logs/` 和 `tmux list-sessions`

### 始终遵守

- **始终 tmux + 实时日志** — 所有 >10s 任务
- **始终 `/loop` 轮询** — 不空等，不手动 `tail -f`
- **始终压缩上下文** — 设置轮询后立即调用 `headroom_compress`，避免长轮询期间上下文无限膨胀
- **绝不说"waiting for X..."然后沉默** — 要么轮询，要么做其他工作
- **估计运行时，设置 2x 超时** — 如果预计 3min，timeout = 6min

See [background-process.md](background-process.md) for full tmux + `/loop` patterns.

### Applied Everywhere

- **Phase 3 (Execute)** — `cargo build --release`, `cargo test --all`, long test suites -> tmux + /loop
- **Phase 4 (E2E)** — dev server + test suite -> tmux + /loop
- **Phase 7 (E2E Verify)** — re-run full e2e after simplify -> tmux + /loop
- **Phase 8 (Commit + Push)** — large repo push -> tmux + /loop
- **Any phase** — docker build, database migration, large file processing -> tmux + /loop

## 铁律 — Commit + Push Mandatory

**所有代码变更必须提交并推送。没有例外。**

旧模式：实现功能 -> "完成" -> 无提交。会话结束工作丢失，无 git 历史，无 PR 记录。
新模式：实现 -> 有意义信息提交 -> 推送到远程 -> "完成"。

- **Phase 3, 4, 5, 6, 7 后必须提交** — 中间提交保证安全
- **Phase 8 最终提交** — 符合项目提交风格的信息
- **必须推送到远程** — `branch`（默认）、`current` 或 `none`（仅用户明确要求不推送）
- **绝不"完成"却不提交** — 未提交的工作等于丢失的工作
- **绝不跳过推送** — 本地提交不防会话丢失

See [shared/commit.md](shared/commit.md) for commit message conventions and push strategies.

### Applied Everywhere

- **Phase 3 (Execute)** — commit after each REQ completes (intermediate safety)
- **Phase 8 (Commit + Push)** — final commit with full message, push to remote
- **Debug (D6)** — commit fix + regression test, push to remote
- **Any code change** — commit before ending session

## 铁律 — MemPalace 读写对称

**MemPalace 调用与 TokenSave 同级别，不可跳过。可用则必做，不可用则静默跳过。**

- **Phase 0 sweep 必须执行**（Type Q/S 除外）— 10 个并行调用加载项目上下文（4 核心 + 4 知识 room + 2 sessions 反馈）
- **`[MP-READ]` 标记的步骤** — 读项目相关历史（spec、决策、实现、bug），为当前 phase 提供上下文
- **`[MP-WRITE]` 标记的步骤** — 写当前 phase 产出（spec、ADR、实现摘要、KG 事实、diary）
- **先读后写** — Phase 0 已做全局 sweep，各 phase 的 `[MP-READ]` 做精准搜索，`[MP-WRITE]` 在 phase 完成后写入
- **MP 不可用** → 任何调用报错 → 静默跳过该 session 所有 MP 步骤，文件系统为主

## 铁律 — 完整工作流不可跳过

**工作流不是建议，是铁律。每个 phase 必须按顺序完成，不允许跳过。**

旧模式：改完代码 -> "完成" -> 跳过 Review/Simplify/E2E -> 直接 commit。这导致代码质量下降、重复逻辑、过度设计、bug 漏检。
新模式：每个 phase 按顺序完成 -> Phase Gate 检查 -> 进入下一 phase。

**Type F（功能）完整流程：**
```
Phase -1 → Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → Phase 7 → Phase 8 → Phase 9 → Phase 9.5 → Phase 10
环境检测   分类       规格      计划     执行     E2E初始   审查    审查+简化   E2E验证   提交推送   清理    完成总结    压缩
```

**禁止行为：**
- **禁止**跳过 Phase 0（分类）直接开始工作 — 不分类不工作，分类结果必须 announce 给用户
- **禁止**跳过 Phase 1（规格）直接写代码 — 没有 spec 不写代码
- **禁止**跳过 Phase 4（E2E）直接进入审查 — 没有 E2E 不审查
- **禁止**跳过 Phase 5-6（Review + Simplify）直接提交 — 没有审查不提交。Phase 8 Pre-Commit Gate 会检查。
- **禁止**跳过 Phase 7（E2E 验证）直接提交 — 简化后必须重新验证
- **禁止**跳过 Phase 8（Commit + Push）说"完成" — 未提交等于丢失
- **禁止**跳过 Phase 10（Session Summary）结束对话 — 不记录统计信息
- **禁止**在 Phase 10 不调用 `headroom_compress` — Phase 10 不完整 = 工作流未结束
- **禁止**在 Phase 0 不创建 TaskCreate task 列表 — 不创建 task = 模型无法跟踪进度 = 跳过
- **禁止**在 Phase 10 完成时 TaskList 还有 `pending` 任务 — 有 pending = 工作流未完整执行

**Phase 完成后必须继续，不能停在中间：**
- Phase 3 完成 → 立即 Phase 4，不要停
- Phase 4 完成 → 立即 Phase 5，不要停
- Phase 5 完成 → 立即 Phase 6，不要停
- Phase 6 完成 → 立即 Phase 7，不要停
- Phase 7 完成 → 立即 Phase 8，不要停
- Phase 8 完成 → 立即 Phase 9，不要停
- Phase 9 完成 → 立即 Phase 9.5，不要停
- Phase 9.5 完成 → 立即 Phase 10，不要停

**唯一合法结束状态是 Phase 10 完成。** 如果要说"完成"而 Phase 10 还没执行，说明你没做完。

**Type Q（查询）极简流程：** Phase 0 → 直接用工具回答 → Phase 10 (仅 headroom_compress)。不创建分支、不写 spec、不 commit。
**Type S（简单）简化流程：** Phase 0 → 直接执行 → Phase 9.5 → Phase 10。简单变更也需 commit + session summary。
**Type B（Bug）调试流程：** Phase 0 → D0-D6 → Phase 8 → Phase 9.5 → Phase 10.

## 铁律 — Grill Enforcement

**Phase 1 必须 grill 用户想法，最低 5 个问题(Type F) / 3 个(Type B)，少于最低 = 未完成 Phase 1 = 不能进入 Phase 2。**

旧模式：用户说"我要 X" -> agent 直接写 REQs。这产生的 spec 遗漏边界情况、不挑战假设、导致错误实现。
新模式：用户说"我要 X" -> agent grill 5+ 问题 -> 基于 grill 写 REQs。

**Grill quality > quantity。** 5 个针对用户请求的具体问题胜过 12 个通用问题。每个问题必须：
- 引用用户请求中的具体细节
- 解释为什么答案重要（答错的后果）
- 提供 2-4 个具体选项，每个选项包含后果 + 权衡 + 项目适配度

**Option quality 是强制的，不是可选的：**
- **Bad:** `label: "Redis", description: "Fast caching"` — 模糊，无上下文
- **Good:** `label: "Redis cache (Recommended)", description: "In-memory -> sub-ms read. Trade-off: needs Redis infra. 适合: 高读低写场景。"`
- 每个选项：**命名方案** + **`->` 后果** + **`Trade-off:`** + **`适合:` 项目适配度**
- 恰好一个 `(Recommended)`，有项目特定的理由

**GRILL CHECKLIST — 所有项目必须在写 REQ 之前完成：**
- [ ] Challenge assumptions — 至少 1 个问题
- [ ] Internet search for existing solutions — Tavily MCP or WebSearch
- [ ] MP search for prior specs/knowledge — `mempalace_search wing="<project>"`
- [ ] Alternative approaches — 至少 1 个问题
- [ ] Scope clarification — 至少 1 个问题

**所有 grill 问题必须使用 AskUserQuestion。** 永不停止等待。

### Applied Everywhere

- **Phase 1 (Spec)** — 3+ grill 问题 before any REQ written
- **Type F (Feature)** — full grill checklist
- **Type B (Bug)** — grill reproduction steps + scope

## 铁律 — 危险操作保护

**涉及数据或代码删除的操作，必须先通过 AskUserQuestion 确认，然后执行。**

- **数据库**：DROP TABLE, TRUNCATE, DELETE/UPDATE 无 WHERE → 先确认
- **文件系统**：rm -rf / rm -r / rm -f → 先确认
- **Git**：push --force, reset --hard, clean -f → 先确认
- **代码**：删除包含业务逻辑的源文件 → 先确认

**子代理同样适用。** 子代理 prompt 必须包含此铁律。

See [dangerous-ops.md](dangerous-ops.md) for full patterns and hook configuration.

## 铁律 — 减少暂停对话

**能一次对话完成的，不拆成多次。减少中断、减少等待、减少用户反复确认。**

旧模式：每个阶段结束都停下来等用户确认 -> 一个功能需要 10 轮对话 -> 用户疲劳、上下文丢失。
新模式：按工作流连续执行 -> 关键决策点用 AskUserQuestion -> 一次对话完成 Phase -1 到 Phase 10。

**核心原则：**
- **连续执行，不停顿** — Phase 完成后立即进入下一 Phase，不等待用户确认
- **关键决策才问用户** — 只有影响架构、安全、数据的决策才用 AskUserQuestion
- **默认值合理就继续** — 用户不回答 -> 用默认值继续，不阻塞
- **后台任务不阻塞** — 长时间任务后台化，轮询期间继续做其他工作
- **一次对话完成整个工作流** — 目标是一次 /doit 调用完成 Phase -1 到 Phase 10

**禁止行为：**
- **禁止**完成一个 Phase 后停止等用户说"继续"
- **禁止**在每个阶段边界都问"是否继续？"
- **禁止**把可以并行的调用串行化（等一个完成再发下一个）
- **禁止**在能推断的情况下问用户（已有信息足够，不要重复确认）

**何时应该暂停：**
- 多个环境冲突需要用户选择
- 删除操作需要确认
- 发现用户需求矛盾，需要澄清
- Phase 9.5 完成总结后等用户反馈

### Applied Everywhere

- **Phase 0 → Phase 1** — 分类后直接开始 grill，不等确认
- **Phase 1 → Phase 2** — Grill 完成直接写 spec，不等确认
- **Phase 3 → Phase 4** — 执行完成直接 E2E，不停
- **Phase 5 → Phase 6** — Review 完成直接 Simplify，不停
- **Phase 8 → Phase 9** — Commit 完成直接清理，不停
- **Any phase** — 多个独立 MCP 调用并行发出，不串行等待

## 铁律 — Review + Simplify 不可跳过

**每次代码变更后，必须经过 Review（Phase 5）和 Simplify（Phase 6）。没有审查的代码不能提交。**

旧模式：改完文件 -> 直接 commit。这导致重复代码、过度抽象、未发现的 bug、README 不同步。
新模式：改完代码 -> Review（找重复、安全漏洞、架构问题） -> Simplify（去冗余、扁平化） -> E2E 验证 -> commit。

**Review 必须检查：**
- 重复代码（相同逻辑出现多次）
- 安全漏洞（OWASP Top 10：注入、XSS、认证绕过）
- 过度抽象（一个操作包 3 层函数）
- 死代码（未使用的函数、变量、import）
- README 是否需要同步更新

**Simplify 必须执行：**
- 合并重复逻辑
- 删除死代码
- 压平不必要的抽象层
- 简化错误处理（只处理可能发生的场景）
- 减少代码行数（200 行能变 50 行，就改）

**禁止行为：**
- **禁止**跳过 Review 直接 commit
- **禁止**跳过 Simplify 直接提交 — "以后再说" = 永远不会做
- **禁止**走过场的 Review（"看起来不错"）— 必须找出具体的问题

---

## 通用编码原则

### Think Before Coding

**不假设。不隐藏困惑。展示权衡。**

- 明确陈述假设 — 不确定时提问而非猜测
- 呈现多种解释 — 模糊时不沉默选择
- 提出更简单方案 — 如果有
- 困惑时停止 — 指出不清楚之处

**应用于：** Phase 1 grill, Phase 2 多方案探索, Phase 0 分类不清时提问

### Brevity First

**用最少的代码解决问题。不过度设计。**

- 不添加需求之外的功能
- 不为一次性代码创建抽象
- 不添加未请求的"灵活性"
- 不处理不可能发生的场景
- 200 行能变 50 行，就改

**应用于：** Phase 3 最小实现, Phase 6 合并冗余, Phase 5 消除重复

### Surgical Edits

**只改必须改的。只清理自己制造的混乱。**

- 不"改进"相邻代码、注释、格式
- 不重构未坏的东西
- 匹配现有风格
- 发现无关死代码 -> 提及，不删除
- 自己的变更产生孤儿代码 -> 清理

**应用于：** Phase 3 只改 Phase 2 确定的文件, Debug 最小变更

### Goal-Driven Execution

**定义成功标准。循环验证直到达成。**

| 不做... | 转化为... |
|-------------|-----------------|
| "添加验证" | "写无效输入测试，让它们通过" |
| "修复 bug" | "写复现测试，让它通过" |
| "重构 X" | "确保重构前后测试都通过" |

**应用于：** Phase 3 每 REQ 可测试验证, Phase 4 真实断言, Phase 7 对比 spec REQ
- **禁止**Simplify 后不重新运行 E2E（Phase 7）— 简化可能破坏功能

## 铁律 — ctx_read 高级模式选择策略
**ctx_read 不是只有 `full` 模式。根据文件特性和任务需求选择最优模式，最大化 token 节省。**
**模式选择决策树（每次 ctx_read 前快速判断）：**
| 场景 | 模式 | 节省 | 信号 |
|------|------|------|------|
| 文件 >500 行，需要完整理解 | `aggressive` | ~90% | 大文件，非编辑 |
| 文件与当前任务相关，需提取相关部分 | `task` | ~85% | 有任务描述，需上下文 |
| 跨会话引用同一文件 | `reference` | ~80% | 需要保留标识符，跨会话 |
| 数据文件、日志、混合内容 | `entropy` | ~70% | JSON, CSV, log, 高熵内容 |
| 编辑后增量验证 | `delta` | ~98% | 刚编辑过，只需变化行 |
| 文件 >500 行，只需结构了解 | `map` | ~95% | 不需要代码内容 |
| 只需函数签名和类型 | `signatures` | ~90% | 理解 API 表面 |
| 编辑文件前 | `full` | 0% | 必须用 full 才能编辑 |
| 已知行范围 | `lines:N-M` | 变动的 | 精确位置 |
| 不确定 | `auto` | 变动的 | 系统自动选择 |
**高级模式使用规则：**
- **>500 行的文件，默认 `aggressive` 而非 `full`** — 首次读取用 `aggressive` 概览，需要编辑时再切 `full`
- **有任务描述时，用 `task` 模式** — 比 `auto` 多省 20-30%，因为会根据任务提取相关部分
- **跨会话场景，用 `reference` 模式** — 保留函数名、变量名等标识符，压缩注释和字符串
- **数据文件（JSON/CSV/XML），用 `entropy` 模式** — 只保留高信息量部分，跳过重复结构
- **编辑后立即验证，用 `delta` 模式** — 只返回变化行，比 `diff` 模式更省
- **批量读取多文件，用 `ctx_multi_read`** — 一次调用替代 N 次，节省 ~3000 token（5-10 个文件）
**禁止：**
- **禁止对大文件 (>500 行) 默认使用 `full` 模式** — 先用 `aggressive`/`map`/`task`，需要编辑再切 `full`
- **禁止在已知行范围时使用 `full` 模式** — 用 `lines:N-M` 精确读取
- **禁止编辑后重新读取整个文件验证** — 用 `delta` 模式只读变化行
- **禁止串行读取 3+ 个文件的 signatures** — 用 `ctx_multi_read` 批量读取
## 铁律 — 无命令不调用 Bash

**每个 Bash/ctx_shell/ctx_execute 调用必须有完整的 command 参数。空 command = InputValidationError = 浪费一轮对话。**

**根本原因：** 模型在思考阶段还没有构造出完整的命令，就提前生成了工具调用。即使思考中说"我需要提供 command 参数"，如果思考中没有出现**完整的、可执行的命令文本**，工具调用仍然会失败。

**强制预检清单（每次调用 Bash 前，思考中必须包含以下内容）：**

```
[BASH PREFLIGHT]
Command: <完整的、可执行的命令文本，包含所有参数>
Reason: <为什么要运行这个命令，一句话>
```

**只有思考中出现了 `[BASH PREFLIGHT]` + 完整的 `Command:` 行，才能生成 Bash 工具调用。** 没有这个标记 = 禁止调用 Bash。

**破坏性循环检测：**
- 如果思考中出现 "I'm stuck in a destructive loop" 或 "need to break it" → **立即停止生成工具调用**
- 回到预检清单，重新写出完整的 `[BASH PREFLIGHT]`
- 认识到问题 ≠ 解决了问题。必须写出完整的命令文本才能继续

**验证检查（每次调用前）：**
- **思考中有 `[BASH PREFLIGHT]` 标记吗？** — 没有 → 先写预检清单
- **`Command:` 行包含完整的命令吗？** — 只有"let me run..."或"export" → 不完整，继续构造
- **command 参数非空？** — 空字符串或纯空白 → 禁止调用
- **重试时命令改变了？** — 如果第一次因为空 command 失败，第二次必须有不同的、完整的命令

**禁止：**
- **先调用 Bash 再想命令** — 命令必须在思考阶段确定
- **用自然语言占位** — "let me run the export" 不是命令
- **重试时不修正** — 如果第一次失败是因为空 command，第二次必须填入实际命令
- **认识问题但不执行预检** — "I need to provide the command" ≠ 提供了命令。必须写出 `[BASH PREFLIGHT]`

### Applied Everywhere

- **Phase 3 (Execute)** — 所有测试命令、构建命令、uv 命令
- **Phase 8 (Commit)** — git 命令必须有完整参数
- **Any phase** — 所有 shell 操作

## 铁律 — InputValidationError 路由

**InputValidationError 不只发生在空 Bash。** 根据错误类型路由到对应的处理文档：

| 错误 | 根因 | 处理文档 |
|------|------|----------|
| `command` 参数为空 | 空 Bash 调用 | 本文件"无命令不调用 Bash" |
| `taskId` 参数缺失 | Compact 后 task 状态丢失 | [errors.md](errors.md)#compact-后-task-丢失 |
| 其他参数缺失 | 工具调用参数不完整 | **[LOAD] [tool-params.md](tool-params.md)** |

**Compact 后遇到 `TaskUpdate` 报错 → 立即查看 [errors.md](errors.md) "Compact 后 Task 丢失"章节。不要重试 TaskUpdate。**
**其他 InputValidationError → [LOAD] [tool-params.md](tool-params.md) 查看工具签名。永远不要用相同参数重试。**

## 铁律 — 不重复相同操作

**每次编辑前，检查最近 3 次操作。如果连续 2 次对同一文件做同类操作，停止。**

旧模式：清理 context_cols → 检查剩余引用 → 继续清理 context_cols → 再检查 → 循环 8 次。每次 Thought 不同但动作相同。
新模式：一次编辑完成所有同类变更 → 验证 → 如果还有，用批量编辑一次性处理 → 停止。

**强制检查（每次 Edit 前）：**
- **最近 3 次操作里，对同一文件的同类编辑出现了几次？**
  - 0-1 次 → 正常执行
  - 2 次 → 最后一次了。用 `tokensave_field_sites` 或 `ctx_search` 一次性找出所有位置，然后用 `tokensave_multi_str_replace` 批量完成
  - 3+ 次 → **停止**。问题不是一次编辑能解决的。重新评估：是否需要全局搜索替换？是否已清理完毕但没验证？

**一次编辑原则：**
- 一次 Edit = 一个完整意图的全部变更，不是分批多次
- 清理类操作（删变量、改引用、去 import）→ 先搜全量 → 一次批量编辑
- 如果 Edit 完成后还需要同类编辑 → 说明第一次没搜全 → 用 `ctx_search` 或 `tokensave_field_sites` 找全 → 再一次性改完

**验证替代重复：**
- 编辑完成后 → `ctx_search` 或 `tokensave_field_sites` 验证是否还有残留
- 有残留 → 批量处理
- 无残留 → 进入下一步，不重复"检查"动作

### Applied Everywhere

- **Phase 3 (Execute)** — 实现时的代码变更
- **Phase 5 (Review)** — 审查时的重复代码合并
- **Phase 6 (Simplify)** — 清理死代码、合并重复逻辑
- **Debug (D6)** — 修复 bug 时的文件修改
