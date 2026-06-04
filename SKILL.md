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

Three persistence layers work together:
- **tokensave** — code graph (symbols, call edges, dependencies). See [plan.md](plan.md).
- **context-mode** — session analytics (token usage, tool patterns). See [execute.md](execute.md).
- **mempalace** — cross-session semantic memory (specs, decisions, implementation notes). See [mempalace.md](mempalace.md).

If any layer is unavailable, the workflow degrades gracefully using the remaining layers.

## Subagent Orchestration

Claude Code's native Agent tool enables parallel task execution across workflow phases. No external plugins required. See [subagent.md](subagent.md) for full patterns.

**Quick reference:**
- **Parallel research** — Phase 1: multiple agents research different aspects concurrently
- **Parallel code analysis** — Phase 2: agents analyze different modules simultaneously
- **Parallel TDD** — Phase 3: independent REQs executed by worktree-isolated agents
- **Parallel review** — Phase 5: security, architecture, complexity reviews run concurrently
- **Background execution** — Any phase: long-running tasks as background agents

**铁律：继承主对话模型。** 不指定 `model` 参数，subagent 继承主对话模型。避免模型不存在错误。

**铁律：同文件不并行。** 修改同一文件的 subagent 必须串行执行。主流程在 Phase 2 规划时构建文件分配表，检查文件交集 → 有交集则串行，无交集则并行。只读操作（review, analysis）天然安全。详见 [subagent.md](subagent.md)。

**Cost model:** Each agent = one API call. Parallel agents reduce total time by 50-70% when tasks are independent.

## Prerequisites

See [setup.md](setup.md) for full tool/skill install manifest.

## Phase -1 — Detect Environment + Config

**Absolute first step. Before anything else.** First check `.doit/env-cache.json` — if same branch and <24h old, skip full scan. Otherwise scan: all virtual env types (conda/uv/venv/poetry/asdf/mise/nvm/...), version pin files (`.python-version`/`.node-version`/`.tool-versions`/...), lock files (`uv.lock`/`poetry.lock`/`package-lock.json`/...), Docker/K8s (`Dockerfile`/`docker-compose`/...), and system info (OS/arch/shell/hooks). Write results to CLAUDE.md `## Environment` section. Multiple envs detected → AskUserQuestion. Cannot determine → AskUserQuestion. Never stop and wait.

Also init `.doit/config.yaml` if not present (default config for doc-capture, commit branch strategy). See [env-check.md](env-check.md) and [doit-config.md](doit-config.md).

## 铁律 — Non-Interruptive Questions

**永远不要停止对话来问用户问题。始终使用 AskUserQuestion 工具。**

旧模式：打印问题 -> 停止 -> 等用户输入。这阻塞工作流、浪费 token、让用户烦躁。
新模式：调用 `AskUserQuestion`，用户无需中断即可回答。Agent 继续执行。

- 绝不写"你选哪个？"然后停下来等
- 绝不写"Wait for user input"然后暂停
- 始终用 `AskUserQuestion` + 2-4 个选项
- 始终提供合理默认值作为第一个选项
- 用户不回答 -> 用默认值继续

## 铁律 — Background Execution

**永远不要空等长时间任务。始终使用后台执行 + 轮询机制。这是铁律，不是建议。**

旧模式：运行 `cargo build --release` -> 干等 5min -> 结果。这阻塞工作流、浪费 token、让用户盯着冻结的 agent。
新模式：后台启动 -> 继续做其他工作 -> 通知时检查结果。

### 决策门控（每个命令运行前必须执行）

在运行任何 Bash 命令前，**必须**先判断：

1. **这个命令预计需要多长时间？**
2. **>10s？** → 禁止前台直接运行，必须后台化
3. **>5min？** → 必须 tmux + Monitor 或 ScheduleWakeup
4. **后台任务设置完成后，是否已设置完成信号（Monitor/ScheduleWakeup）？** → 没有则禁止继续

### 三级执行标准

- **<10s** → 直接 Bash（前台 OK）
- **10s–5min** → `Bash run_in_background=true` 或 shell `&` + log 文件 + `[START]`/`[END]` 标记 + **必须设置 Monitor 轮询**
- **>5min** → tmux 命名 session + Monitor + 自动继续，或 `ScheduleWakeup` 定期轮询

### 强制轮询规则

**每个后台任务必须有一个对应的轮询机制。没有轮询的后台任务 = 丢失的工作。**

- `Bash run_in_background=true` → Claude Code 自动通知，但仍需设置 timeout
- Shell `&` → **必须**配合 `Monitor` 命令设置文件检查
- tmux → **必须**配合 `Monitor` 命令 + `[END]` 标记检查
- **禁止**启动后台任务后不做任何轮询设置

### 轮询期间必须做其他工作

**设置后台任务 + Monitor 后，必须立即继续其他工作。** 空等 Monitor 触发 = 违反铁律。
如果无其他工作可做，使用 `ScheduleWakeup` 定期轮询（延迟 >= 60s）。

### 禁止行为

- **禁止**运行长时间命令后停止响应、沉默等待
- **禁止**重复 `tail -f` 或频繁 `cat` 日志文件来手动轮询（用 Monitor 或 ScheduleWakeup）
- **禁止**忘记设置完成信号（`[END]` 标记、Monitor、ScheduleWakeup）
- **禁止**对后台任务不设 timeout（默认 300s）
- **禁止**在长对话中忘记后台任务的存在 → 用户问进度时立即检查 `.scratch/logs/` 和 tmux sessions

### 始终遵守

- **始终设置完成信号** — `[END]` 标记、Monitor 检查或 ScheduleWakeup 回调
- **绝不说"waiting for X..."然后沉默** — 要么轮询，要么做其他工作
- **估计运行时，设置 2x 超时** — 如果预计 3min，timeout = 6min

See [background-process.md](background-process.md) for full three-tier patterns.

## 铁律 — Commit + Push Mandatory

**所有代码变更必须提交并推送。没有例外。**

旧模式：实现功能 -> "完成" -> 无提交。会话结束工作丢失，无 git 历史，无 PR 记录。
新模式：实现 -> 有意义信息提交 -> 推送到远程 -> "完成"。

- **Phase 3, 4, 5, 6, 7 后必须提交** — 中间提交保证安全
- **Phase 8 最终提交** — 符合项目提交风格的信息
- **必须推送到远程** — `branch`（默认）、`current` 或 `none`（仅用户明确要求不推送）
- **绝不"完成"却不提交** — 未提交的工作等于丢失的工作
- **绝不跳过推送** — 本地提交不防会话丢失

## 铁律 — MemPalace 读写对称

**MemPalace 调用与 TokenSave 同级别，不可跳过。可用则必做，不可用则静默跳过。**

- **Phase 0 sweep 必须执行**（Type S 除外）— 4 个并行调用加载项目上下文
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
- **禁止**跳过 Phase 10（Compact）结束对话 — 不压缩上下文

**Phase 完成后必须继续，不能停在中间：**
- Phase 3 完成 → 立即 Phase 4，不要停
- Phase 4 完成 → 立即 Phase 5，不要停
- Phase 5 完成 → 立即 Phase 6，不要停
- Phase 6 完成 → 立即 Phase 7，不要停
- Phase 7 完成 → 立即 Phase 8，不要停
- Phase 8 完成 → 立即 Phase 9，不要停
- Phase 9 完成 → 立即 Phase 9.5，不要停
- Phase 9.5 完成 → 立即 Phase 10，不要停

**唯一合法结束状态是 Phase 10 compact。** 如果要说"完成"而上下文还没压缩，说明你没做完。

**Type S（简单）简化流程：** Phase 0 → 直接执行 → Phase 9.5 → Phase 10。简单变更也需 commit + compact。
**Type B（Bug）调试流程：** Phase 0 → D0-D6 → Phase 8 → Phase 9.5 → Phase 10。

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

## Principles

Seven principles guide every phase. Six iron rules. See [principles.md](principles.md).

| Principle | What it prevents |
|-----------|------------------|
| **Non-Interruptive Questions (铁律)** | blocking workflow, wasted tokens, user frustration |
| **Background Execution (铁律)** | idle waiting, frozen agent, dead conversation time |
| **Commit + Push Mandatory (铁律)** | lost work, no git history, no PR trail |
| **MemPalace 读写对称 (铁律)** | lost context across sessions, repeated research |
| **完整工作流不可跳过 (铁律)** | skipped phases, degraded quality, bugs shipped |
| **Review + Simplify 不可跳过 (铁律)** | unreviewed code, duplication, over-engineering |
| **Think Before Coding** | wrong assumptions, hidden confusion, missing trade-offs |
| **Brevity First** | over-engineering, bloated abstractions |
| **Surgical Edits** | unrelated edits, touching code that shouldn't be touched |
| **Goal-Driven Execution** | vague success criteria, constant clarification |

Per-phase application:
- **Phase 1 (Spec)** — think before coding: grill ideas, challenge assumptions, present alternatives
- **Phase 3 (Execute)** — goal-driven (testable verification per REQ), brevity first (minimal code per REQ)
- **Phase 3-8** — background execution: ALL >10s commands run in background with Monitor/ScheduleWakeup polling. Decision gate before every Bash command. No exceptions.
- **Phase 3-8** — commit + push: every code change committed and pushed
- **Phase 5-6 (Review + Simplify)** — surgical edits (only touch what's necessary), brevity first (remove unnecessary abstractions)
- **Debug (D2 Fix)** — surgical edits (minimum change for regression test pass)

## Phase 0 — Classify Request

**Step 0 — Sync with remote (MANDATORY, before anything else).** If the project has a git remote, pull latest:
```bash
if git remote 2>/dev/null | grep -q .; then
  git pull --rebase 2>/dev/null || git pull 2>/dev/null || true
fi
```
**Why:** avoids working on stale code, prevents conflicts. `|| true` so network errors don't block.

**Step 1 — Load doit + caveman skills for the entire session.** Call the Skill tool to load both. These are Tool calls, not code comments:

```
Skill skill="doit"
Skill skill="caveman"
```

If caveman skill is not found, announce `[WARN] caveman not installed -> verbose mode` and continue. CLAUDE.md `## Skill Loading` section (written by Phase -1) also enforces this, so even if this step is skipped, the CLAUDE.md instruction should trigger skill load.

**Step 2 — Auto-classify.** Read [classifier.md](classifier.md). Four types:

- **R (resume)** — `/doit` called with no args or blank args. Resume in-progress workflow. See classifier.md Type R.
- **S (simple)** — single file, rename, quick fix. Execute directly. Skip phases 1-6.
- **F (feature)** — new functionality, cross-module, user-facing. Run phases 1-8.
- **B (bug)** — something broken. Run debug workflow D0-D6. See [debug.md](debug.md).

**Classify, announce type to user, proceed. If user disputes type, use their type.**

**Step 2.5 — Memory Context Sweep (MANDATORY).** Before any phase logic executes, load project context from MemPalace. Type S (simple) can skip.

**Step A — Refresh index (sequential, must complete first):**
```
mempalace_reconnect
```

**Step B — Core context (ALL 4 in parallel, no dependencies):**
```
mempalace_diary_read agent_name="doit" last_n=5
mempalace_kg_query entity="<project>"
mempalace_kg_timeline entity="<project>"
mempalace_search query="<用户请求关键词>" wing="<project>" limit=5
```

**Type R (resume) append:** `mempalace_search query="<project> resume in-progress" wing="<project>" limit=3`
**Type B (bug) append:** `mempalace_search query="<bug 关键词> error" wing="<project>" room="bugs" limit=5`

If MemPalace unavailable (any call errors) → skip all MP steps silently for this session. Filesystem remains primary.

**Before proceeding: check if user's prompt contains reference documentation.** If yes, capture it before any phase runs. See [doc-capture.md](doc-capture.md). Doc capture is independent of classification type (R/S/F/B) — always run first.

## Doc Capture (Pre-Phase)

If the user's prompt includes reference documents (API specs, business rules, conventions), save to `.doit/docs/`, verify tokensave index, and inject CLAUDE.md reference. This ensures future sessions can find the docs via tokensave search. See [doc-capture.md](doc-capture.md).

## Phase 1 — Spec

Write spec. See [spec.md](spec.md). Grill user ideas ruthlessly — armed with MemPalace context from Phase 0 sweep. Internet search via Tavily MCP for brainstorming. Search MemPalace for related prior specs. Split into acceptance criteria (REQ-001, REQ-002...). Save to `.spec/current.md`.

## Phase 2 — Plan

Check TokenSave code graph. Map impact at symbol and coupling level. Produce implementation order. See [plan.md](plan.md).

## Phase 3 — Execute

TDD loop per acceptance criteria. See [execute.md](execute.md). Start each REQ with tokensave_context for code understanding. RTK for all shell commands. uv for Python. Context-Mode for context management. Interactive spec alignment after each TDD cycle. Per-REQ review+simplify built in. Full e2e happens after Phase 6.

## Phase 4 — E2E (initial)

End-to-end tests in real env. See [e2e.md](e2e.md). L0+L1 auto, L2+L3 HITL. Run after Phase 3 unit tests complete.

## Phase 5 — Review

Feature-level review. Merge duplicate logic. Minimal refactor. See [review.md](review.md).
If caveman skill available, run `/caveman-review` for caveman-style code review before tokensave analysis.

## Phase 6 — Review + Simplify

Review what you wrote. Find duplicates, over-engineering, missed README updates. Simplify. See [review-simplify.md](review-simplify.md). **NEVER skip this step.** After this, enters Phase 7 E2E Verification loop.

## Phase 7 — E2E Verification Loop

Re-run e2e tests after Review + Simplify. Compare actual output against spec REQs (not just test assertions). If mismatch → fix code to match spec, not test to match code. Loop until e2e passes AND output matches spec. See [shared/e2e-verify.md](shared/e2e-verify.md).

## Phase 8 — Commit + Push

Stage changed files, commit with meaningful message matching project's commit style, update spec status, and push to remote. See [commit.md](commit.md).
If caveman skill available, run `/caveman-commit` for caveman-style commit message generation.

**Auto-push (no confirmation needed):** read `.doit/config.yaml` commit.branch:
- `branch` (default) — create `feat/...` or `fix/...` branch and push
- `current` — push current branch
- `none` — commit only, skip push

## Phase 9 — Cleanup

Remove all intermediate workflow files. See [commit.md](shared/commit.md) step 8.

- `.spec/current.md` — remove (archived in Phase 5)
- `.spec/doc-capture.md` — remove (temp file)
- `.scratch/` directory — remove if empty

**Keep:** `.spec/archive/`, `.doit/config.yaml`, `.doit/docs/`

## Phase 9.5 — Completion Summary

**Before compact, tell the user what was done and what to do next.** This is the last visible output before context compression. See [commit.md](shared/commit.md) Gate section for format.

Must include:
- Branch, commit hash, change summary
- What each REQ delivered
- **Actionable next steps** — concrete commands to run, features to test, services to restart

**No vague "done" messages.** User needs to know: "what do I do now?"

## Phase 10 — Auto-Compact

After Phase 9.5 completion summary, automatically trigger context compression to reduce token usage for the next session:

1. **RTK token report** (if available):
   - `rtk gain` — show total session token savings
   - `rtk gain --history` — per-command savings breakdown
2. **Context-Mode stats** (if available): `ctx stats` — log session token savings
3. **MemPalace diary** (if available):
   - `mempalace_diary_write agent_name="doit" entry="<compact summary>" topic="compact"`
   - `mempalace_memories_filed_away` → verify auto-save checkpoint was saved
   - `mempalace_kg_timeline entity="<project>"` → log project timeline for future reference
4. **Caveman compress** (if available): Run `/caveman:compress CLAUDE.md` to compress CLAUDE.md using caveman's built-in compression skill. Falls back to step 5 if caveman unavailable.
5. **MANDATORY: Run `/compact`** — execute the Claude Code built-in compaction command. Type `/compact` as a user message. Do NOT skip. Do NOT say "done" without compacting.

**This phase always runs last.** It ensures the conversation context is compressed before the session ends, reducing token overhead for resumed conversations.

## Error Handling

See [errors.md](errors.md). Spec fail = discard. Execute fail = re-grill. Review fail = retain on branch. MemPalace unavailable = skip memory steps, filesystem remains primary.

## Persistence

Spec in git (`feature/xxx` branch). No runtime state file — workflow progress tracked by git branch, commit history, spec files, and MemPalace (if available).

**MemPalace layers** (see [mempalace.md](mempalace.md)): spec archive, implementation notes, knowledge graph facts, and agent diary entries survive session restarts. Complements filesystem state for cross-session resume.

**Background process logs** (see [background-process.md](background-process.md)): long-running commands output to `.scratch/logs/` with clear exit signals for process state detection. Three tiers: foreground (<10s), background with log file (10s-5min), tmux + monitor (>5min, auto-continuation).

## Resume

Workflow spans multiple conversation turns. If `/doit` is called again, determine current phase from context and filesystem.

**Blank `/doit` (no arguments) = always resume.** Never start a new workflow when user types `/doit` without a request.

1. **Same session** — conversation history already tracks progress
2. **Cross-session** (new conversation, same project):

```
On feature branch (feat/xxx or fix/xxx)?
  → Work in progress, inspect further:

  .spec/current.md exists?
    → Spec written (Phase 1+), check REQ-xxx statuses for execution progress
    .spec/archive/ has files?
      → Phase 5+ completed
    git diff --stat shows uncommitted changes?
      → Middle of a phase
    git log -1 contains phase info?
      → Commit message may indicate last completed phase
  No spec files, no feature branch?
    → Tell user: "No in-progress workflow found. Type /doit <your request> to start."
```

**MemPalace recovery** (if available, before filesystem check):
```
mempalace_diary_read agent_name="doit" last_n=3
mempalace_search query="<project> <feature>" wing="<project>" limit=5
mempalace_kg_query entity="<project>"
```
This recovers what was done in prior sessions without relying on filesystem state alone. See [mempalace.md](mempalace.md) for full integration.

## Phase Gate Checklist — DO NOT SKIP

**After completing ANY phase, run this checklist before ending your response.** The conversation may continue, but the workflow MUST complete all phases. Code changes alone are NEVER the end of a doit session.

```
[Phase Gate] Type R flow (resume):
  [x] Phase 0     Classify → detect in-progress work
  [x] Resume from detected phase → complete remaining phases
  [x] Phase 9.5   Completion Summary (user-facing)
  [x] Phase 10    Auto-Compact

[Phase Gate] Type F flow (full):
  [x] Phase -1    Detect Environment + Config
  [x] Phase 0     Classify Request
  [x] Phase 1     Spec (grill → write → branch)
  [x] Phase 2     Plan (impact analysis)
  [x] Phase 3     Execute (TDD per REQ)
  [x] Phase 4     E2E (initial tests)
  [x] Phase 5     Review
  [x] Phase 6     Review + Simplify
  [x] Phase 7     E2E Verification Loop
  [x] Phase 8     Commit + Push
  [x] Phase 9     Cleanup intermediate files
  [x] Phase 9.5   Completion Summary (user-facing)
  [x] Phase 10    Auto-Compact
  [x] Doc Capture (if user prompt has docs)

[Phase Gate] Type S flow (simple):
  [x] Phase 0   Classify
  [x] Execute directly
  [x] Phase 9.5 Completion Summary (user-facing)
  [x] Phase 10  Auto-Compact
  [x] Doc Capture (if user prompt has docs)

[Phase Gate] Type B flow (bug):
  [x] Phase 0   Classify
  [x] D0-D6     Debug workflow (debug.md)
  [x] Phase 8   Commit + Push
  [x] Phase 9.5 Completion Summary (user-facing)
  [x] Phase 10  Auto-Compact
```

**After Phase 3 completes:** always continue to Phase 4. Never stop at "tests pass, done."
**After Phase 6 completes:** always continue to Phase 7. E2E verification after simplification.
**After Phase 7 completes:** always continue to Phase 8. Every feature ships committed + pushed.
**After Phase 8 completes:** always continue to Phase 9. Clean up intermediate files.
**After Phase 9 completes:** always continue to Phase 9.5. Present completion summary to user.
**After Phase 9.5 completes:** always continue to Phase 10. Compact conversation context.

**The only valid end state is Phase 10 compact.** If you're about to say "done" or "completed" and context has not been compacted, you haven't finished.
