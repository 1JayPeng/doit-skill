## Phase 0 — Classify Request (完整流程)

**铁律：Phase -1 必须先于 Phase 0 完成。** 模型首先应该对环境有个快速清晰的认知：编码环境、CLI 环境、bash 环境、code 环境、agent 环境、上下文。

**Step -1 — Environment Detection (MANDATORY, absolute first step):**

Before doing ANYTHING else (including sync with remote), execute [core/env-check.md](env-check.md):

1. **Check env cache:** If `.doit/env-cache.json` exists and is <24h old and `.git/HEAD` hasn't changed → use cached values (fast path)
2. **If cache miss or expired:** Run full Phase -1 environment detection:
   - Detect project type (Cargo.toml, package.json, go.mod, etc.)
   - Detect coding environment (language, runtime, versions)
   - Detect CLI environment (Claude Code, OpenCode, Codex, oh-my-pi, MiMo, etc.)
   - Detect bash environment (shell, tools available)
   - Detect code environment (git status, branch, recent commits)
   - Detect agent environment (MCP tools, skills, memory layers)
   - Detect context (session memory, MemPalace, prior findings)
3. **Build CLI Tool Guide** (Step 8b of env-check) — inject tool mapping into `[[CONFIG:main-instructions]]`
4. **Announce environment summary** to user: detected CLI, project type, key tools available, any warnings

**铁律：不完成 Step -1 就不能进入 Step 0。不了解环境就分类 = 盲分类 = 可能选错工作流。**

**Step 0 — Sync with remote (MANDATORY, after env detection):**
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

**Step 2 — Auto-classify (with codegraph orientation).** Read [classifier.md](../classifier.md). Five types:

Before classifying, build a quick code map to understand the codebase structure. This informs classification accuracy:

```
[CALL] codegraph_context(task="quick overview of project structure and main modules for request classification")
```

**Why:** A request that touches 1 file vs 10 modules changes classification (S vs F). Codegraph gives the map in one call — no grep+read loops.
**Rule:** If codegraph unavailable → fall back to `ctx_overview` + `[[FILE:read]]` of project entry points.

For Type F, the `codegraph_context` result becomes Phase 2's starting point — don't re-query, just narrow with `codegraph_impact`/`codegraph_search`.

**铁律: 分类结果必须 announce 给用户，格式为 `## Phase 0: 分类 → Type X`。**

**Announcement format:**
```
## Phase 0: 意图分类

分类: Type X (reason)
流程: Phase 0 → [phases based on type]
```

**Step 2.1 — Proxy Status Check:**
1. Check if `ANTHROPIC_BASE_URL` contains `127.0.0.1:8787` → `[PROXY] headroom active`
2. If not, check proxy health: `curl -sf http://127.0.0.1:8787/health` (success → `[PROXY] headroom active`)
3. If proxy not running but `headroom.proxy.enabled: true` in config → `[PROXY-FALLBACK] headroom proxy down, using upstream ($_hr_upstream)`
4. If proxy not configured or disabled → announce nothing (MCP tools still available as fallback)

**Step 2.25 — Context Orientation (MANDATORY, Type Q/S can skip):**
```
[CALL] ctx_overview(path=".", task="<user request>") — project map
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

If `subagent.enabled: false` → continue with single-agent flow. (Default is `true`.)

See [core/subagent.md](core/subagent.md) for full team orchestration details.

**Step 2.8 — Clean Stale Tasks (MANDATORY, before creating new task list).**

Before creating new tasks, identify and remove tasks from previous workflow runs:

1. Call `[[TASK:list]]` to get current task list
2. Identify stale tasks — any task with subject containing "Phase" or "REQ-" that is in `pending` or `in_progress` status from a previous workflow run
3. Delete each stale task with `[[TASK:update taskId="..." status="deleted"]]` (or `completed` if the CLI doesn't support `deleted`)
4. For file-based task management (`.doit/tasks.md`), truncate the file before creating new tasks

**铁律：不清理旧 tasks 就创建新的 = 任务列表混乱 = 模型无法判断哪些是当前工作流的任务。**

**Step 3 — Create Phase Task List (MANDATORY).**

Execute ALL `[[TASK:create]]` calls in parallel:

```
# Type F (full feature workflow):
[[TASK:create subject="Phase 0 - Classify" description="Classify request, announce type, create task list"]]
[[TASK:create subject="Phase 1 - Spec" description="Grill 4+ questions, write spec, create branch"]]
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
