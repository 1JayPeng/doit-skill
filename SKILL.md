---
name: doit
description: >
  Full spec-driven, TDD-based development workflow. Auto-classifies requests into
  simple/feature/bug, routes to correct flow, and enforces spec alignment through
  every step. Use when user states any requirement, feature request, or idea that
  involves writing or modifying code. Triggers on: "我想做", "帮我加", "我需要",
  "add feature", "implement", "I want to", "build", or any request that implies
  new functionality.
---

# Do It

Spec-driven TDD workflow. Every feature passes through 10 phases. Nothing ships without spec. Every change must pass Review + Simplify, E2E Verification, and git commit before proceeding.

## Memory Layer

Five persistence layers work together:
- **tokensave** — code graph (symbols, call edges, dependencies). See [plan.md](plan.md).
- **context-mode** — session analytics (token usage, tool patterns). See [execute.md](execute.md).
- **agentmemory** — cross-session semantic memory (default). 53 MCP tools, 12 hooks, 4 skills. See [agentmemory.md](agentmemory.md).
- **mempalace** — cross-session semantic memory (alternative). See [mempalace.md](mempalace.md).
- **headroom** — token optimization via CCR (Compress-Cache-Retrieve) proxy compression. See [headroom.md](headroom.md).

**Default memory layer: agentmemory.** If agentmemory is unavailable, falls back to mempalace. If any layer is unavailable, the workflow degrades gracefully using the remaining layers.

## 铁律 — 工作留痕

**每个 phase 完成后必须记录工作日志。三层存储：agentmemory > mempalace > `.doit/worklog.json`。**

- 记录内容：phase、REQ、描述、耗时、文件变更、决策、阻塞项、测试结果
- 记录失败不阻塞工作流 → 继续下一个 phase，但 Phase 9.5 声明 `[WARN] worklog failed`
- 记录要具体 → "实现认证 API" 而非 "写代码"
- 用途：生成日报/周报/项目报告

See [worklog.md](worklog.md) for format, storage layers, and report generation.

## Subagent Orchestration

Claude Code's native Agent tool enables parallel task execution. See [subagent.md](subagent.md) for full patterns.

**Config gate:** Read `.doit/config.yaml` `subagent.enabled`. If `false` (default), execute all REQs sequentially — skip all Agent tool calls. If `true`, enable Conductor Orchestration mode.

**铁律：** 继承主对话模型（不指定 `model` 参数）、同文件不并行、Conductor 模式不写代码、规则完整注入、危险操作保护。详见 [subagent.md](subagent.md)。

**Cost model:** Each agent = one API call. Parallel agents reduce total time by 50-70% when tasks are independent, but cost 2x-4x tokens.

## Prerequisites

See [setup.md](setup.md) for full tool/skill install manifest.

## Phase -1 — Detect Environment + Config

**Absolute first step. Before anything else.** First check `.doit/env-cache.json` — if same branch and <24h old, skip full scan. Otherwise scan: all virtual env types (conda/uv/venv/poetry/asdf/mise/nvm/...), version pin files (`.python-version`/`.node-version`/`.tool-versions`/...), lock files (`uv.lock`/`poetry.lock`/`package-lock.json`/...), Docker/K8s (`Dockerfile`/`docker-compose`/...), and system info (OS/arch/shell/hooks). Write results to CLAUDE.md `## Environment` section. Multiple envs detected → AskUserQuestion. Cannot determine → AskUserQuestion. Never stop and wait.

Also init `.doit/config.yaml` if not present (default config for doc-capture, commit branch strategy). See [env-check.md](env-check.md) and [doit-config.md](doit-config.md).

## 铁律

所有铁律详情见 [rules.md](rules.md)。执行对应 phase 前，**必须**读取相关铁律。

| 铁律 | 核心约束 | 详情 |
|------|---------|------|
| **Non-Interruptive Questions** | 永远用 AskUserQuestion，永不停止等待 | [rules.md](rules.md) |
| **Background Execution** | >10s 命令禁止前台运行，必须后台化 + 轮询 | [rules.md](rules.md) — 决策门控、三级标准、轮询规则 |
| **Commit + Push Mandatory** | 所有代码变更必须提交并推送，没有例外 | [rules.md](rules.md) |
| **MemPalace 读写对称** | MP 调用与 TokenSave 同级别，可用则必做 | [rules.md](rules.md) |
| **完整工作流不可跳过** | 每个 phase 必须按顺序完成，唯一合法结束是 Phase 10 | [rules.md](rules.md) — 流程图、禁止行为 |
| **Grill Enforcement** | Phase 1 必须 grill 5+ 问题(Type F) / 3+ (Type B)，少于最低不进入 Phase 2 | [rules.md](rules.md) |
| **危险操作保护** | 删除操作必须先 AskUserQuestion 确认 | [rules.md](rules.md) |
| **Review + Simplify 不可跳过** | 代码变更后必须 Review + Simplify，未审查不提交 | [rules.md](rules.md) — 检查清单 |

## Principles

See [principles.md](principles.md). 8 iron rules + 4 guiding principles. Key per-phase mapping:
- **Phase 1** — think before coding: grill ideas, challenge assumptions
- **Phase 3** — goal-driven + brevity first: minimal code per REQ
- **Phase 3-8** — background execution (>10s -> bg + poll) + commit + push
- **Phase 5-6** — surgical edits + brevity: remove unnecessary abstractions

## Token 优化工具

三个 token 优化工具协同工作，各自覆盖不同场景。**强制使用，不是可选的。**

| 工具 | 触发条件 | 调用方式 | 节省 |
|------|---------|---------|------|
| **RTK** | 所有 Bash 命令 | 自动（PreToolUse hook） | 26% |
| **lean-ctx** | 读文件、搜索、shell 命令 | 手动调用 MCP 工具 | 15% |
| **headroom** | 工具输出 >500 行 | 手动调用 compress/retrieve | 70-90% |

### RTK — 自动 Bash 压缩

PreToolUse hook 自动将 Bash 命令重写为 `rtk <command>`。模型无需感知，自动生效。
- `git status` → `rtk git status` (500 token → 50)
- `cargo build` → `rtk cargo build` (2000 token → 200)
- 已配置，无需模型操作

### lean-ctx — 缓存 + 压缩

**优先使用 lean-ctx MCP 工具，而非原生工具。** 缓存机制让重复读取 ~13 token。

| 原生工具 | lean-ctx 替代 | 何时用 |
|---------|-------------|--------|
| `Read` | `ctx_read(path, mode)` | 读文件 |
| `Grep` | `ctx_search(pattern, path)` | 搜索代码 |
| `Bash` (ls/find) | `ctx_tree(path, depth)` | 列目录 |
| `Bash` (大输出) | `ctx_shell(command)` | 执行命令 |

**强制规则：**
- 读文件 → `ctx_read` (不是一次性读取，有缓存)
- 搜索 → `ctx_search` (比 Grep 输出小 60%)
- 列目录 → `ctx_tree` (比 ls 输出小 80%)
- 大输出命令 → `ctx_shell` (自动压缩 95+ 模式)

### headroom — 大输出压缩

**当任何工具返回 >500 行输出时，先压缩再处理。** 压缩后只保留 hash + 摘要，需要时再 retrieve。

```
# 压缩大输出
headroom_compress(large_tool_output)  → 返回 hash + 小摘要

# 需要完整内容时
headroom_retrieve(hash)  → 还原完整内容
```

**强制规则：**
- 工具输出 >500 行 → `headroom_compress` 先压缩
- 压缩后处理摘要，需要细节时 `headroom_retrieve`
- Phase 10 压缩前检查 headroom 统计

### 使用决策树

```
工具调用 → 什么类型？
├─ Bash 命令 → RTK 自动处理 (无需操作)
├─ 读文件 → ctx_read(path, mode)
├─ 搜索代码 → ctx_search(pattern, path)
├─ 列目录 → ctx_tree(path, depth)
├─ 执行命令 → ctx_shell(command)
└─ 大输出 (>500 行) → headroom_compress(output) → 处理摘要
```


每个 phase 的描述包含 **[CALL]** 指令 — 必须执行的 MCP 工具调用，和 **[LOAD]** 指令 — 必须读取的文件。

**[CALL] = 工具调用，必须执行。[LOAD] = 文件读取，必须阅读后执行。** 两者都不可跳过。

### Phase 0 — Classify Request

**[LOAD] [phases.md](phases.md)#phase-0 — 完整流程：Sync remote, Load skills (caveman + grill-me), Auto-classify, MP sweep (10 并行调用), Type-specific 逻辑。**

Sync remote → Load skills → Auto-classify (R/S/F/B) → Memory Context Sweep (10 parallel MP calls) → Doc capture.

**[CALL] MP sweep 10 并行调用** (详见 phases.md): reconnect, diary_read, kg_query, kg_timeline, search (project + 4 knowledge rooms + 2 sessions). 如果 agentmemory 可用，额外 `agentmemory_recall`。

### Doc Capture (Pre-Phase)

If the user's prompt includes reference documents (API specs, business rules, conventions), save to `.doit/docs/`, verify tokensave index, and inject CLAUDE.md reference. See [doc-capture.md](doc-capture.md).

### Phase 1 — Spec

**[LOAD] [phases.md](phases.md)#phase-1 — 完整 grill 协议 (5+ 问题 Type F / 3+ Type B)、uncertainty scan、Phase 1→2 gate。**

**[LOAD] [learn/inject.md](learn/inject.md) — 知识注入：搜索相关历史 session、注入 top-3 到上下文。**

**[CALL]** `agentmemory_recall query="<用户请求>" limit=3`, `mempalace_search query="<用户请求>" wing="<project>" limit=3`, `mempalace_search query="<用户请求>" wing="sessions" room="general" limit=3`.

Knowledge injection → Grill FIRST (5+ AskUserQuestion with structured options) → Internet search → MP search → Write spec → Create branch → Gate check.

**铁律：Grill 最低 5 个问题(Type F) / 3 个(Type B)。** 少于最低 = 未完成的 Phase 1 = 不能进入 Phase 2。

### Phase 2 — Plan

**[LOAD] [learn/inject.md](learn/inject.md) — 知识注入：搜索相关历史案例、注入 top-3。**

**[CALL]** `tokensave_context task="<用户请求>"` (PRIMARY), `agentmemory_recall query="<用户请求> implementation" limit=3`.

Knowledge injection → tokensave_context → Check TokenSave code graph. Map impact at symbol and coupling level. Produce implementation order. See [plan.md](plan.md).
**Phase 2 完成后：** 记录工作日志（影响分析结果、实现顺序、预计工时）。See [worklog.md](worklog.md)。

### Phase 3 — Execute

**[CALL]** Subagent decision gate (Read `.doit/config.yaml` `subagent.enabled`), `tokensave_context task="<REQ description>"` per REQ, `ctx_batch_execute` for parallel calls.

TDD loop per acceptance criteria. See [execute.md](execute.md). Start each REQ with tokensave_context. RTK for all shell commands (auto via hook). uv for Python. Context-Mode for context management. **headroom_compress** for any tool output >500 lines. Interactive spec alignment after each TDD cycle. Per-REQ review+simplify built in. Full e2e happens after Phase 6.
**Phase 3 完成后：** 记录工作日志（每个 REQ 的 TDD 结果、耗时、文件变更）。See [worklog.md](worklog.md)。

### Phase 4 — E2E (initial)

**[CALL]** `ctx_batch_execute` — Run E2E tests in parallel

End-to-end tests in real env. See [e2e.md](e2e.md). L0+L1 auto, L2+L3 HITL. Run after Phase 3 unit tests complete.
**Phase 4 完成后：** 记录工作日志（E2E 测试结果、覆盖率）。See [worklog.md](worklog.md)。

### Phase 5 — Review

**[CALL]** `tokensave_context task="<review scope>"`, `tokensave_dead_code`, `tokensave_complexity`.

Feature-level review. Merge duplicate logic. Minimal refactor. See [review.md](review.md).
If caveman skill available, run `/caveman-review` for caveman-style code review before tokensave analysis.
**Phase 5 完成后：** 记录工作日志（Review 发现的问题、严重程度）。See [worklog.md](worklog.md)。

### Phase 6 — Review + Simplify

**[CALL]** `tokensave_diff_context files=["<changed files>"]` — Impact analysis

Review what you wrote. Find duplicates, over-engineering, missed README updates. Simplify. See [review-simplify.md](review-simplify.md). **NEVER skip this step.** After this, enters Phase 7 E2E Verification loop.
**Phase 6 完成后：** 记录工作日志（Simplify 删除的代码行数、合并的函数数）。See [worklog.md](worklog.md)。

### Phase 7 — E2E Verification Loop

**[CALL]** `ctx_batch_execute` — Re-run E2E tests

Re-run e2e tests after Review + Simplify. Compare actual output against spec REQs (not just test assertions). If mismatch → fix code to match spec, not test to match code. Loop until e2e passes AND output matches spec. See [shared/e2e-verify.md](shared/e2e-verify.md).
**Phase 7 完成后：** 记录工作日志（E2E 验证结果、循环次数）。See [worklog.md](worklog.md)。

### Phase 8 — Commit + Push

**[CALL]** `agentmemory_recall query="commit style" limit=3` — Learn commit message style

Stage changed files, commit with meaningful message matching project's commit style, update spec status, and push to remote. See [commit.md](commit.md).
**Phase 8 完成后：** 记录工作日志（最终 commit hash、变更统计 +X/-Y 行）。See [worklog.md](worklog.md)。
If caveman skill available, run `/caveman-commit` for caveman-style commit message generation.

**Auto-push (no confirmation needed):** read `.doit/config.yaml` commit.branch:
- `branch` (default) — create `feat/...` or `fix/...` branch and push
- `current` — push current branch
- `none` — commit only, skip push

### Phase 9 — Cleanup

Remove all intermediate workflow files. See [commit.md](shared/commit.md) step 8.

- `.spec/current.md` — remove (archived in Phase 5)
- `.spec/doc-capture.md` — remove (temp file)
- `.scratch/` directory — remove if empty

**Keep:** `.spec/archive/`, `.doit/config.yaml`, `.doit/docs/`

### Phase 9.5 — Completion Summary + Knowledge Extraction

**[LOAD] [phases.md](phases.md)#phase-9.5 — 完成总结格式、知识提取清单、KG facts。**

**[CALL]** `mempalace_check_duplicate` + `mempalace_add_drawer` (extract knowledge), `agentmemory_remember content="<knowledge JSON>"`.

Present completion summary to user → Extract knowledge (code/api/db/flow) → Announce extraction count.

### Phase 9.5.5 — Knowledge Distillation

**[LOAD] [learn/extract.md](learn/extract.md) — 结构化知识提取、用户确认、多层存储。**

Extract structured session knowledge → User confirmation → Save to agentmemory + mempalace + context-mode + filesystem. See [learn/](learn/) module.

### Phase 10 — Session Summary

**[LOAD] [phases.md](phases.md)#phase-10 — 步骤：RTK report, Context-Mode stats, Headroom compression, MemPalace diary, Caveman compress。**

**[CALL]** `rtk gain`, `ctx_stats`, `headroom_stats`, `mempalace_diary_write agent_name="doit" entry="<summary>"`, `agentmemory_remember content="<session summary JSON>"`, `mempalace_kg_stats`.

RTK token report → Context-Mode stats → Headroom compression → agentmemory + MemPalace diary → Caveman compress

**This phase always runs last.** It gathers session statistics and preserves knowledge for future sessions.

## Error Handling

See [errors.md](errors.md). Spec fail = discard. Execute fail = re-grill. Review fail = retain on branch. MemPalace unavailable = skip memory steps, filesystem remains primary.

## Persistence

Spec in git (`feature/xxx` branch). Workflow progress tracked by git branch, commit history, spec files, and MemPalace (if available).

**MemPalace layers** (see [mempalace.md](mempalace.md)): spec archive, implementation notes, knowledge graph facts, and agent diary entries survive session restarts.

**Background process logs** (see [background-process.md](background-process.md)): long-running commands output to `.scratch/logs/` with clear exit signals.

## Resume

**[LOAD] [phases.md](phases.md)#resume — 跨会话恢复逻辑、MemPalace recovery、文件系统检查。**

**Blank `/doit` (no arguments) = always resume.** Never start a new workflow when user types `/doit` without a request.

## Phase Gate Checklist — DO NOT SKIP

**[LOAD] [phases.md](phases.md)#phase-gate — 完整 Phase Gate 检查清单（Type R/F/S/B 全部流程）。**

**After completing ANY phase, run this checklist before ending your response.** The conversation may continue, but the workflow MUST complete all phases. Code changes alone are NEVER the end of a doit session.

**After Phase 3 completes:** always continue to Phase 4. Never stop at "tests pass, done."
**After Phase 6 completes:** always continue to Phase 7. E2E verification after simplification.
**After Phase 7 completes:** always continue to Phase 8. Every feature ships committed + pushed.
**After Phase 8 completes:** always continue to Phase 9. Clean up intermediate files.
**After Phase 9 completes:** always continue to Phase 9.5. Present completion summary to user.
**After Phase 9.5 completes:** always continue to Phase 9.5.5. Extract structured knowledge.
**After Phase 9.5.5 completes:** always continue to Phase 10. Gather session statistics and preserve knowledge.

**The only valid end state is Phase 10 complete.** If you're about to say "done" or "completed" and Phase 10 has not run, you haven't finished.
