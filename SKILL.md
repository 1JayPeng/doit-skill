---
name: doit
description: "Spec-driven TDD workflow. Auto-classifies simple/feature/bug. Triggers: 我想做, 帮我加, 我需要, add feature, implement, I want to, build."
---

# Do It

Spec-driven TDD. 10 phases. Nothing ships without spec. Review + Simplify + E2E + commit mandatory.

**Multi-CLI Support:** Claude Code, OpenCode, OpenAI Codex CLI, oh-my-pi, MiMo Code, and any MCP-supporting agent. Tool adapter auto-selected at install time via `--agent` flag.

**Phase 0 是强制入口。** 任何 `/doit` 调用，必须先执行 Phase 0 分类，然后 announce 分类结果给用户，然后创建 Phase Task List（`[[TASK:create]]`）。不 announce = 用户不知道工作流在做什么 = 跳过。不创建 task 列表 = 模型无法跟踪进度 = 跳过。

**Type Q 例外：** 纯查询/研究工作不需要完整工作流。分类为 Type Q → 直接用工具回答 → Phase 10 (仅 `[[MEMORY:compress]]`)。

## Load Order

1. **[core/workflow.md](core/workflow.md)** — Phase 0-10 workflow definition (tool-agnostic)
2. **[core/iron-rules.md](core/iron-rules.md)** — Iron rules (tool-agnostic)
3. **[adapters/[AGENT_TYPE].md](adapters/claude-code.md)** — Tool adapter (selected at install)
4. **[core/env-check.md](core/env-check.md)** — Environment detection
5. Phase files on-demand via [LOAD:phase-N] directives

## Skill Router

On-demand load. **[RELEASE]** after phase + `[[MEMORY:compress]]`。
caveman: Phase 0 [LOAD:session] 不释放 | grill-me: Phase 1 [LOAD:phase-1] 结束释放 | tdd: Phase 3 [LOAD:phase-3] 结束释放 | diagnose: Phase 0 Type B | handoff/prototype: 按需 | improve-codebase-architecture: 按需

## 铁律 + 指令 + 工具

[core/iron-rules.md](core/iron-rules.md)。Worklog: 每 phase 记录 (mempalace > `.doit/worklog.json`)。[worklog.md](worklog.md)
Non-Interruptive Q | Background >10s | Commit+Push | MP 读写对称 | 工作流不可跳过 | 减少暂停 | Grill 5+/3+ | 危险操作确认 | Review+Simplify
**[CALL]** = MCP。**[LOAD]** = 读文件。**[LOAD:phase-N]** = 加载 skill。**[RELEASE:phase-N]** = 释放 + `[[MEMORY:compress]]`。
5 层: codegraph, lean-ctx, context-mode, headroom (Proxy 60-95% 节省), mempalace。MCP 工具链在所有支持的 CLI 中保持一致。
**Subagent: 默认启用** (`subagent.enabled: true`)。三级团队 [core/subagent.md](core/subagent.md)。[core/team-roles.md](core/team-roles.md)

## Phase Index

| Phase | [LOAD] | 说明 |
|-------|--------|------|
| **-1** | [core/env-check.md](core/env-check.md) | 环境检测 → `[[CONFIG:main-instructions]]` + config |
| **0** | [core/phase-0.md](core/phase-0.md) | Sync → [LOAD:session] caveman → 分类(R/S/F/B) → MP sweep → **`[[TASK:create]]` task list** |
| **1** | [core/phase-1.md](core/phase-1.md), [learn/inject.md](learn/inject.md) | [LOAD:phase-1] grill-me → Grill(5+/3+) via `[[USER:ask]]` → Spec → Branch → Gate → [RELEASE:phase-1] |
| **2** | [learn/inject.md](learn/inject.md), [plan.md](plan.md) | codegraph_context → Impact → Order |
| **3** | [core/execute.md](core/execute.md) | [LOAD:phase-3] tdd → TDD per REQ → per-REQ review+simplify |
| **4** | [e2e.md](e2e.md) | E2E real env, L0+L1 auto, L2+L3 HITL |
| **5** | [review.md](review.md) | Feature review, merge duplicates |
| **6** | [core/shared/review-simplify.md](core/shared/review-simplify.md) | Duplicates, over-engineering。**不可跳过** |
| **7** | [core/shared/e2e-verify.md](core/shared/e2e-verify.md) | Re-run E2E vs spec REQs |
| **8** | [core/shared/commit.md](core/shared/commit.md) | Stage → commit → push |
| **9** | — | 清理 `.spec/current.md`, `.spec/doc-capture.md`, empty `.scratch/` |
| **9.5** | [core/workflow.md](core/workflow.md)#phase-9.5 | Summary → Knowledge extraction |
| **9.5.5** | [learn/extract.md](learn/extract.md) | 结构化知识 → 用户确认 → 多层存储 |
| **10** | [core/workflow.md](core/workflow.md)#phase-10 | Stats → MP → **`[[MEMORY:compress]]`** |

**Phase Gate:** 3→4→5→6→7→8→9→9.5→9.5.5→10。**唯一合法结束 = Phase 10。**
**Type Q 流程:** Phase 0 → 直接用工具回答 → Phase 10 (仅 `[[MEMORY:compress]]`)。不创建分支、不写 spec、不 commit。

## 辅助

文档 → `.doit/docs/` + codegraph。[doc-capture.md](doc-capture.md), [errors.md](errors.md)。Spec in git + MemPalace。Logs: `.scratch/logs/`。
**[LOAD] [core/workflow.md](core/workflow.md)#resume。Blank `/doit` = always resume。**

## Abstract Operations Reference

| Operation | Description | Resolved by |
|-----------|-------------|-------------|
| `[[TASK:create]]` | Create task | Adapter → TaskCreate / todowrite / shell |
| `[[TASK:update]]` | Update task status | Adapter → TaskUpdate / todowrite / sed |
| `[[TASK:list]]` | List tasks | Adapter → TaskList / cat |
| `[[AGENT:spawn]]` | Launch subagent | Adapter → Agent({}) / @subagent / codex |
| `[[AGENT:message]]` | Message subagent | Adapter → SendMessage / N/A |
| `[[AGENT:stop]]` | Stop subagent | Adapter → TaskStop / kill |
| `[[USER:ask]]` | Ask user | Adapter → AskUserQuestion / question |
| `[[FILE:read]]` | Read file | Adapter → Read / read / cat |
| `[[FILE:write]]` | Write file | Adapter → Write / write / heredoc |
| `[[FILE:edit]]` | Edit file | Adapter → Edit / edit / patch |
| `[[SHELL:run]]` | Run command | Adapter → Bash / bash / shell |
| `[[SCHEDULE:wakeup]]` | Schedule wakeup | Adapter → ScheduleWakeup / sleep |
| `[[SKILL:route]]` | Route to skill | Adapter → Skill({}) / load markdown |
| `[[MEMORY:compress]]` | Compress context | MCP → headroom_compress |
| `[[WEB:fetch]]` | Fetch URL | Adapter → WebFetch / webfetch / curl |
| `[[WEB:search]]` | Search web | Adapter → WebSearch / websearch |

## Config Variables

| Variable | Description | Example Values |
|----------|-------------|----------------|
| `[[CONFIG:main-instructions]]` | Project instructions file | CLAUDE.md, AGENTS.md |
| `[[CONFIG:skill-dir]]` | Skills directory | .claude/skills/, .opencode/skills/, .omp/skills/, .mimo/skills/ |
| `[[CONFIG:global-skill-dir]]` | Global skills | ~/.claude/skills/, ~/.opencode/skills/, ~/.config/omp/skills/, ~/.config/mimo/skills/ |
| `[[CONFIG:settings-file]]` | Settings file | .claude/settings.json, .opencode/settings.json |
| `[[CONFIG:mcp-config]]` | MCP config | ~/.claude.json, ~/.opencode/mcp.json |
