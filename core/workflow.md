# Core Workflow — Phase Details (Tool-Agnostic)

**This file contains phase execution steps using `[[OPERATION]]` abstract syntax.**
**See [adapters/](../adapters/) for tool-specific mappings.**


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
3. [LOAD:phase-1] grill-me → Grill (4+/3+ questions via `[[USER:ask]]`)
4. Write spec to `.spec/current.md`
5. [RELEASE:phase-1] grill-me → `[[MEMORY:compress]]`

## Phase 2 — Plan

**[LOAD] [plan.md](plan.md) — impact analysis, REQ ordering, wave schedule.**

Key steps:
1. codegraph_context for impact analysis
2. MemPalace proactive query
3. Build dependency graph
4. Wave schedule (if subagent enabled)
5. Write plan to .doit/plan.md

## Phase 3 — Execute

**[LOAD] [execute.md](execute.md) — full Phase 3 TDD execution.**

Key steps:
1. [LOAD:phase-3] tdd
2. TDD loop per REQ
3. Per-REQ review + simplify

When `subagent.enabled: true`: dispatch Developers per REQ via wave schedule. See [core/subagent.md](core/subagent.md).

## Phase 4 — E2E

**[LOAD] [e2e.md](e2e.md) — end-to-end tests in real environment.**

Key steps:
1. L0: Re-run unit tests (auto)
2. L1: Integration tests (auto)
3. L2: System tests (HITL)
4. L3: Acceptance tests (HITL)
5. E2E report to .doit/e2e-report.md**

## Phase 5 — Review

**[LOAD] [review.md](review.md) — feature review against spec.**

Key steps:
1. Diff review (all changes)
2. REQ-by-REQ verification against spec
3. Cross-REQ consistency check
4. Code quality scan (issues feed Phase 6)**

## Phase 6 — Simplify

**[LOAD] [shared/review-simplify.md](shared/review-simplify.md) — review + simplify.**

## Phase 7 — E2E Verify

**[LOAD] [shared/e2e-verify.md](shared/e2e-verify.md) — E2E verification loop.**

## Phase 8 — Commit + Push

**[LOAD] [shared/commit.md](shared/commit.md) — commit + push.**

## Phase 9 — Cleanup

Remove `.spec/current.md`, `.spec/doc-capture.md`, empty `.scratch/`.

## Phase 9.5 — Completion Summary + Knowledge Extraction

**Step 0 — Task Closure (MANDATORY, before generating any summary).**

Before telling the user what was done, audit ALL tasks and close them. This prevents stale pending tasks from triggering system warnings and ensures the task list accurately reflects completion.

1. Call `[[TASK:list]]` to get current task state
2. For each task:
   - If status is `in_progress` → `[[TASK:update taskId="..." status="completed"]]`
   - If status is `pending` and the phase was intentionally skipped → `[[TASK:update taskId="..." status="deleted"]]`
   - If status is `pending` and the phase was NOT executed (omission) → `[[TASK:update taskId="..." status="completed"]]` with note
3. Verify all tasks are closed: call `[[TASK:list]]` again, confirm no `pending` or `in_progress` tasks remain

**铁律：Phase 9.5 不先关任务就直接输出 Summary = 遗留 stale tasks = 系统警告。**

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

**[LOAD] [learn/extract.md](learn/extract.md) — full extraction + multi-layer storage.**

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
