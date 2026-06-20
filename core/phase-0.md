## Phase 0 — Classify Request (完整流程)

**Step 0 — Sync with remote (MANDATORY, before anything else):**
```bash
if git remote 2>/dev/null | grep -q .; then
  git pull --rebase 2>/dev/null || git pull 2>/dev/null || true
fi
```

**Step 1 — Load doit + caveman skills. [LOAD:session] caveman.**
```
[[SKILL:route target="doit"]]
[[SKILL:route target="caveman"]]
```
If caveman not found, announce `[WARN] caveman not installed -> verbose mode` and continue.

**分类驱动额外 skill 加载:**
- Type F → Phase 1 [LOAD:phase-1] grill-me, Phase 3 [LOAD:phase-3] tdd
- Type B → now [LOAD:phase-0] diagnose → `[[SKILL:route target="diagnose"]]`
- Type Q/R/S → no extra skills

**Step 2 — Auto-classify.** Read [classifier.md](../classifier.md). Five types:
- **R (resume)** — `/doit` called with no args. Resume in-progress workflow.
- **Q (query)** — pure query/research, no code changes. Skip phases 1-9.5.
- **S (simple)** — single file, rename, quick fix. Skip phases 1-6.
- **F (feature)** — new functionality, cross-module, user-facing. Run phases 1-8.
- **B (bug)** — something broken. Run debug workflow D0-D6.

**铁律: 分类结果必须 announce 给用户，格式为 `## Phase 0: 分类 → Type X`。**

**Announcement format:**
```
## Phase 0: 意图分类

分类: Type X (reason)
流程: Phase 0 → [phases based on type]
```

**Step 2.1 — Proxy Status Check:** If `ANTHROPIC_BASE_URL` contains `127.0.0.1:8787`, announce `[PROXY] headroom active`. If not set but config has `headroom.proxy.enabled: true`, offer to start proxy.

**Step 2.25 — Context Orientation (MANDATORY, Type Q/S can skip):**
```
[CALL] ctx_repomap(max_tokens=2048) — PageRank repo map
[CALL] ctx_session(action="status") — session memory status
[CALL] ctx_knowledge(action="wakeup") — surface prior findings
```

**Step 2.5 — Memory Context Sweep (MANDATORY).** Type Q and Type S can skip.

**Step A — Refresh index:**
```
mempalace_reconnect
```

**Step B — Extended sweep (ALL in parallel):**
```
mempalace_diary_read agent_name="doit" last_n=5
mempalace_kg_query entity="<project>"
mempalace_kg_timeline entity="<project>"
mempalace_search query="<用户请求关键词>" wing="<project>" limit=5 max_distance=0.7
mempalace_search wing="<project>" room="knowledge_code" limit=3 max_distance=0.7
mempalace_search wing="<project>" room="knowledge_api" limit=3 max_distance=0.7
mempalace_search wing="<project>" room="knowledge_db" limit=3 max_distance=0.7
mempalace_search wing="<project>" room="knowledge_flow" limit=3 max_distance=0.7
mempalace_search wing="sessions" room="general" limit=3 max_distance=0.7
mempalace_search wing="sessions" room="problems" limit=3 max_distance=0.7
```

**CRITICAL: `wing="<project>"` is mandatory on every `mempalace_search`.**

**Search relevance gate:** `similarity >= 0.3` → use content. `< 0.3` → treat as empty.

If MemPalace unavailable → skip silently. Filesystem remains primary.

**Step 2.75 — Subagent Team Bootstrap (if `subagent.enabled: true`).**

Read `.doit/config.yaml`. If `subagent.enabled: true`:

1. **[LOAD] [core/team-roles.md](core/team-roles.md)** — load role definitions
2. **Determine team size** based on classification:
   - Type S → no subagents, main flow directly
   - Type F, small (<3 REQs) → Conductor + Developer × N
   - Type F, large (3+ REQs) → Conductor + Architect + Developer × N + Reviewer + Tester
   - Type B → Conductor + diagnose skill
3. **Prepare wave schedule** — after Phase 2, Architect produces the dependency graph and wave schedule
4. **Announce** `[TEAM] subagent mode active (<team_size> roles)`

If `subagent.enabled: false` or not set → continue with single-agent flow.

See [core/subagent.md](core/subagent.md) for full team orchestration details.

**Step 3 — Create Phase Task List (MANDATORY).**

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

**铁律: 不创建 task list = Phase 0 未完成 = 工作流未开始。**

**[CALL] After creating tasks, verify with [[TASK:list]].**
