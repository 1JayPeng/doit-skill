# Core Workflow — Phase Details (Tool-Agnostic)

**This file contains phase execution steps using `[[OPERATION]]` abstract syntax.**
**See [adapters/](../adapters/) for tool-specific mappings.**

**指令集:** **[LOAD]** = must-read file. **[LOAD:phase-N]** = load phase-N skill. **[RELEASE:phase-N]** = release skill + `[[MEMORY:compress]]`. **[CALL]** = MCP tool call (MCP is tool-agnostic).

## 指令集 — Progressive Disclosure

**[LOAD]** = must-read file.
**[LOAD:phase-N] skill-name** = load skill at phase N start.
**[RELEASE:phase-N] skill-name** = release skill + `[[MEMORY:compress]]` at phase N end.
**[LOAD:session] skill-name** = load for full session, no [RELEASE].

| 指令 | 语义 | 示例 |
|------|------|------|
| `[LOAD:phase-0] diagnose` | Load diagnose at Phase 0 (Type B) | `[[SKILL:route target="diagnose"]]` |
| `[LOAD:phase-1] grill-me` | Load grill-me at Phase 1 | `[[SKILL:route target="grill-me"]]` |
| `[RELEASE:phase-1] grill-me` | Release + compress | Context freed |
| `[LOAD:phase-3] tdd` | Load tdd at Phase 3 | `[[SKILL:route target="tdd"]]` |
| `[LOAD:session] caveman` | Load at Phase 0, keep for session | No release |
| `[LOAD:on-demand]` | handoff/prototype/improve-codebase-architecture | User triggers directly |

**Skill 加载策略:**
- caveman: Phase 0 [LOAD:session] 不释放
- grill-me: Phase 1 [LOAD:phase-1] 开始 → [RELEASE:phase-1] 结束释放
- tdd: Phase 3 [LOAD:phase-3] 开始 → [RELEASE:phase-3] 结束后释放
- diagnose: Phase 0 Type B [LOAD:phase-0] → [RELEASE:phase-0] D6 完成后释放
- handoff/prototype/improve-codebase-architecture: 按需加载，完成后立即释放
- **Subagent team mode:** See [core/team-roles.md](core/team-roles.md) for Architect/Developer/Reviewer/Tester roles.

## Phase 0 — Classify Request

**[LOAD] [phase-0.md](phase-0.md) — full Phase 0 execution.**

Key steps:
1. Sync with remote
2. Load doit + caveman skills
3. Auto-classify (R/Q/S/F/B)
4. Context orientation + Memory sweep
5. **[[TASK:create]]** task list based on type
6. Mark Phase 0 complete

## Phase 1 — Spec

**[LOAD] [phase-1.md](phase-1.md) — full Phase 1 execution.**

Key steps:
1. Read config
2. Knowledge injection
3. [LOAD:phase-1] grill-me → Grill (5+/3+ questions via `[[USER:ask]]`)
4. Write spec to `.spec/current.md`
5. [RELEASE:phase-1] grill-me → `[[MEMORY:compress]]`

## Phase 2 — Plan

**[LOAD] [../plan.md](../plan.md) — full Phase 2 execution.**

Key steps:
1. codegraph_context for impact analysis
2. MemPalace proactive query
3. Build execution order

## Phase 3 — Execute

**[LOAD] [execute.md](execute.md) — full Phase 3 TDD execution.**

Key steps:
1. [LOAD:phase-3] tdd
2. TDD loop per REQ
3. Per-REQ review + simplify

When `subagent.enabled: true`: dispatch Developers per REQ via wave schedule. See [core/subagent.md](core/subagent.md).

## Phase 4 — E2E

**[LOAD] [../e2e.md](../e2e.md) — full Phase 4 execution.**

## Phase 5 — Review

**[LOAD] [../review.md](../review.md) — full Phase 5 execution.**

## Phase 6 — Simplify

**[LOAD] [../shared/review-simplify.md](../shared/review-simplify.md) — review + simplify.**

## Phase 7 — E2E Verify

**[LOAD] [../shared/e2e-verify.md](../shared/e2e-verify.md) — E2E verification loop.**

## Phase 8 — Commit + Push

**[LOAD] [../shared/commit.md](../shared/commit.md) — commit + push.**

## Phase 9 — Cleanup

Remove `.spec/current.md`, `.spec/doc-capture.md`, empty `.scratch/`.

## Phase 9.5 — Completion Summary + Knowledge Extraction

**Before Phase 10, tell the user what was done.** Language: user's configured language (default: 中文).

Must include: branch, commit hash, change summary, REQ delivery, actionable next steps.

### Knowledge Extraction (MANDATORY)

**[CALL] Execute ALL MCP tool calls:**
```
[CALL] ctx_shell("git diff --stat HEAD~1..HEAD")
[CALL] ctx_shell("git log -1 --format='%s'")
```

Extract knowledge per category (code, api, db, flow) → MemPalace + KG facts.

## Phase 9.5.5 — Knowledge Distillation

**[LOAD] [../learn/extract.md](../learn/extract.md) — full extraction + multi-layer storage.**

## Phase 10 — Session Summary

**[CALL] Execute ALL:**

1. RTK token report: `ctx_shell("rtk gain")`
2. lean-ctx stats: `ctx_stats()`
3. Context-Mode stats: `ctx stats`
4. Headroom stats: `headroom_stats` (MCP — works regardless of proxy status; proxy mode also supports `headroom proxy stats` for live traffic)
5. MemPalace KG + diary: `mempalace_diary_write`, `mempalace_kg_stats`
6. Session decision: `ctx_session(action="decision", ...)`
7. Caveman compress CLAUDE.md

**Phase 10 hard gate — `[[MEMORY:compress]]` is last step, cannot skip.**

## Phase 0 Task List Creation

**铁律: 不创建 task list = Phase 0 未完成 = 工作流未开始。**

Execute ALL `[[TASK:create]]` calls in parallel:

```
# Type F (full feature workflow):
[[TASK:create subject="Phase 0 - Classify" description="Classify request, announce type, create task list"]]
[[TASK:create subject="Phase 1 - Spec" description="Grill 5+ questions, write spec, create branch"]]
[[TASK:create subject="Phase 2 - Plan" description="Impact analysis, codegraph context, order REQs"]]
[[TASK:create subject="Phase 3 - Execute" description="TDD per REQ, per-REQ review+simplify"]]
[[TASK:create subject="Phase 4 - E2E" description="End-to-end tests in real environment"]]
[[TASK:create subject="Phase 5 - Review" description="Feature review, merge duplicates"]]
[[TASK:create subject="Phase 6 - Simplify" description="Remove dead code, flatten abstractions"]]
[[TASK:create subject="Phase 7 - E2E Verify" description="Re-run E2E vs spec REQs"]]
[[TASK:create subject="Phase 8 - Commit+Push" description="Pre-commit gate, commit, push to remote"]]
[[TASK:create subject="Phase 9 - Cleanup" description="Remove intermediate files, keep archive"]]
[[TASK:create subject="Phase 9.5 - Summary" description="Completion summary, knowledge extraction"]]
[[TASK:create subject="Phase 10 - Session End" description="Stats, MP diary, [[MEMORY:compress]]"]]
```

```
# Type Q (query workflow):
[[TASK:create subject="Phase 0 - Classify" description="Classify request, announce Type Q"]]
[[TASK:create subject="Query" description="Use tools to research and answer directly"]]
[[TASK:create subject="Phase 10 - Compact" description="[[MEMORY:compress]]"]]
```

```
# Type S (simple workflow):
[[TASK:create subject="Phase 0 - Classify" description="Classify request, announce type"]]
[[TASK:create subject="Execute" description="Execute the simple change directly"]]
[[TASK:create subject="Phase 9.5 - Summary" description="Completion summary"]]
[[TASK:create subject="Phase 10 - Session End" description="Stats, [[MEMORY:compress]]"]]
```

```
# Type B (bug workflow):
[[TASK:create subject="Phase 0 - Classify" description="Classify request, announce type"]]
[[TASK:create subject="D0-D6 Debug" description="Debug workflow per debug.md"]]
[[TASK:create subject="Phase 8 - Commit+Push" description="Commit fix, push to remote"]]
[[TASK:create subject="Phase 9.5 - Summary" description="Completion summary"]]
[[TASK:create subject="Phase 10 - Session End" description="Stats, [[MEMORY:compress]]"]]
```

```
# Type R (resume): Create tasks for remaining phases from detected phase.
```

**After creating tasks, mark Phase 0 as done:**
```
[[TASK:update taskId="<phase0_task_id>" status="completed"]]
```

**At each phase boundary:**
```
[[TASK:update taskId="<phase_task_id>" status="in_progress"]]  # at phase start
[[TASK:update taskId="<phase_task_id>" status="completed"]]   # at phase end
```

**[CALL] After creating tasks, verify with [[TASK:list]].** The task list should show all phases as `pending`.

## Resume — Cross-Session Recovery

**Blank `/doit` (no arguments) = always resume.**

1. **Same session** — conversation history tracks progress
2. **Cross-session** — check feature branch, `.spec/current.md`, REQ statuses, git diff

**MemPalace recovery** (if available):
```
mempalace_diary_read agent_name="doit" last_n=3
mempalace_search query="<project> <feature>" wing="<project>" limit=5
mempalace_kg_query entity="<project>"
```
