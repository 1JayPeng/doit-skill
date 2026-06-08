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
- 用户不回答 -> 用默认值继续
- **例外：grill 问题不适用此规则。** grill 问题必须先被提出，然后用户不回答才用默认值。跳过 grill 问题 ≠ 用户不回答。

### Applied Everywhere

- **Phase -1 (Env Detection)** — env conflict -> AskUserQuestion with detected envs as options
- **Phase 1 (Spec)** — grill -> AskUserQuestion for each clarification
- **Phase 3 (Execute)** — spec alignment -> AskUserQuestion "Proceed to next REQ?"
- **Phase 4 (E2E)** — L2/L3 HITL -> AskUserQuestion "Which combo needs testing?"
- **Debug (D0)** — reproduction steps unclear -> AskUserQuestion

## 铁律 — Background Execution

**永远不要空等长时间任务。始终使用后台执行 + 轮询机制。这是铁律，不是建议。**

旧模式：运行 `cargo build --release` -> 干等 5min -> 结果。这阻塞工作流、浪费 token、让用户盯着冻结的 agent。
新模式：后台启动 -> 继续做其他工作 -> 通知时检查结果。

### 决策门控（每个命令运行前必须执行）

在运行任何 Bash 命令前，**必须**先判断：

1. **这个命令预计需要多长时间？**
2. **>10s？** → 禁止前台直接运行，必须后台化
3. **>10s？** → 必须后台 + `/loop` 轮询（推荐）
4. **>30min？** → 必须 tmux + Monitor（多阶段 pipeline）
5. **后台任务设置完成后，是否已设置完成信号（`/loop` 推荐、Monitor 备选）？** → 没有则禁止继续

### 三级执行标准

- **<10s** → 直接 Bash（前台 OK）
- **10s–30min** → shell `&` + log 文件 + `/loop` 轮询（推荐）+ ScheduleWakeup
- **>30min** → tmux 命名 session + Monitor + 自动继续

### 强制轮询规则

**每个后台任务必须有一个对应的轮询机制。没有轮询的后台任务 = 丢失的工作。**

- `Bash run_in_background=true` → Claude Code 自动通知，但仍需设置 timeout
- Shell `&` → **必须**配合 `/loop` 轮询（推荐）或 Monitor 命令
- tmux → **必须**配合 `Monitor` 命令 + `[END]` 标记检查
- **禁止**启动后台任务后不做任何轮询设置

### 轮询期间必须做其他工作

**设置后台任务 + `/loop` 后，必须立即继续其他工作。** 空等 loop 触发 = 违反铁律。
如果无其他工作可做，`/loop` 期间主 agent 可以继续其他任务。

### 禁止行为

- **禁止**运行长时间命令后停止响应、沉默等待
- **禁止**重复 `tail -f` 或频繁 `cat` 日志文件来手动轮询（用 `/loop` 或 Monitor）
- **禁止**忘记设置完成信号（`[END]` 标记、`/loop`、Monitor、ScheduleWakeup）
- **禁止**对后台任务不设 timeout（默认 300s）
- **禁止**在长对话中忘记后台任务的存在 → 用户问进度时立即检查 `.scratch/logs/` 和 tmux sessions

### 始终遵守

- **始终设置完成信号** — `[END]` 标记、`/loop` 轮询、Monitor 检查或 ScheduleWakeup 回调
- **绝不说"waiting for X..."然后沉默** — 要么轮询，要么做其他工作
- **估计运行时，设置 2x 超时** — 如果预计 3min，timeout = 6min

See [background-process.md](background-process.md) for full three-tier patterns.

### Applied Everywhere

- **Phase 3 (Execute)** — `cargo build --release`, `cargo test --all`, long test suites -> background
- **Phase 4 (E2E)** — dev server + test suite -> tmux + monitor
- **Phase 7 (E2E Verify)** — re-run full e2e after simplify -> background + monitor
- **Phase 8 (Commit + Push)** — large repo push -> background with log
- **Any phase** — docker build, database migration, large file processing -> background tier matching duration

## 铁律 — Commit + Push Mandatory

**所有代码变更必须提交并推送。没有例外。**

旧模式：实现功能 -> "完成" -> 无提交。会话结束工作丢失，无 git 历史，无 PR 记录。
新模式：实现 -> 有意义信息提交 -> 推送到远程 -> "完成"。

- **Phase 3, 4, 5, 6, 7 后必须提交** — 中间提交保证安全
- **Phase 8 最终提交** — 符合项目提交风格的信息
- **必须推送到远程** — `branch`（默认）、`current` 或 `none`（仅用户明确要求不推送）
- **绝不"完成"却不提交** — 未提交的工作等于丢失的工作
- **绝不跳过推送** — 本地提交不防会话丢失

See [commit.md](commit.md) for commit message conventions and push strategies.

### Applied Everywhere

- **Phase 3 (Execute)** — commit after each REQ completes (intermediate safety)
- **Phase 8 (Commit + Push)** — final commit with full message, push to remote
- **Debug (D6)** — commit fix + regression test, push to remote
- **Any code change** — commit before ending session

## 铁律 — MemPalace 读写对称

**MemPalace 调用与 TokenSave 同级别，不可跳过。可用则必做，不可用则静默跳过。**

- **Phase 0 sweep 必须执行**（Type S 除外）— 10 个并行调用加载项目上下文（4 核心 + 4 知识 room + 2 sessions 反馈）
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
- **禁止**跳过 Phase 1（规格）直接写代码 — 没有 spec 不写代码
- **禁止**跳过 Phase 4（E2E）直接进入审查 — 没有 E2E 不审查
- **禁止**跳过 Phase 5-6（Review + Simplify）直接提交 — 没有审查不提交
- **禁止**跳过 Phase 7（E2E 验证）直接提交 — 简化后必须重新验证
- **禁止**跳过 Phase 8（Commit + Push）说"完成" — 未提交等于丢失
- **禁止**跳过 Phase 10（Session Summary）结束对话 — 不记录统计信息

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
- **禁止**Simplify 后不重新运行 E2E（Phase 7）— 简化可能破坏功能
