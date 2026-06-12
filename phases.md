# Phase Details — 按需加载

**本文件包含 Phase 的详细执行步骤。SKILL.md 仅保留索引 + [LOAD] 指令。执行对应 phase 前，模型必须读取本节。**

**指令集:** **[LOAD]** = 必须读取的文件。**[LOAD:phase-N]** = phase 专用 skill 加载（如 [LOAD:phase-1] grill-me）。**[RELEASE:phase-N]** = skill 释放 + ctx_compress 压缩上下文。**[CALL]** = 必须执行的 MCP 工具调用。

## 指令集 — Progressive Disclosure

**[LOAD]** = 必须读取的文件（与原有语义不变）。
**[LOAD:phase-N] skill-name** = 在 phase N 开始时加载指定 skill（`Skill skill="skill-name"`）。
**[RELEASE:phase-N] skill-name** = 在 phase N 结束时释放指定 skill + 调用 `ctx_compress` 压缩上下文。
**[LOAD:session] skill-name** = 加载后全程驻留，不参与 [RELEASE]（仅 behavior 型 skill 使用）。

| 指令 | 语义 | 示例 |
|------|------|------|
| `[LOAD:phase-1] grill-me` | Phase 1 开始时加载 grill-me skill | `Skill skill="grill-me"` |
| `[RELEASE:phase-1] grill-me` | Phase 1 结束后释放 + ctx_compress | 上下文释放 |
| `[LOAD:session] caveman` | Phase 0 加载，全程驻留 | 不释放 |

**Skill 加载策略:** grill-me 不在 Phase 0 加载。它在 Phase 1 开始时 [LOAD:phase-1] 加载，Phase 1 结束时 [RELEASE:phase-1] 释放。caveman 全程驻留。

## Phase 0 — Classify Request (完整流程)

**Step 0 — Sync with remote (MANDATORY, before anything else).** If the project has a git remote, pull latest:
```bash
if git remote 2>/dev/null | grep -q .; then
  git pull --rebase 2>/dev/null || git pull 2>/dev/null || true
fi
```
**Why:** avoids working on stale code, prevents conflicts. `|| true` so network errors don't block.

**Step 1 — Load doit + caveman skills. [LOAD:session] caveman.** Call the Skill tool for doit + caveman only. **Do NOT load grill-me here.** grill-me loads at Phase 1 start via [LOAD:phase-1].

```
Skill skill="doit"
Skill skill="caveman"
```

If caveman skill is not found, announce `[WARN] caveman not installed -> verbose mode` and continue.
CLAUDE.md `## Skill Loading` section (written by Phase -1) also enforces this, so even if this step is skipped, the CLAUDE.md instruction should trigger skill load.

**分类驱动额外 skill 加载:**
- Type F → Phase 1 开始时 [LOAD:phase-1] grill-me, Phase 3 开始时 [LOAD:phase-3] tdd
- Type B → 现在 [LOAD:phase-0] diagnose
- Type R/S → 无额外 skill

**Step 2 — Auto-classify.** Read [classifier.md](classifier.md). Four types:

- **R (resume)** — `/doit` called with no args or blank args. Resume in-progress workflow. See classifier.md Type R.
- **S (simple)** — single file, rename, quick fix. Execute directly. Skip Phase -1 (use env-cache if available). Skip phases 1-6.
- **F (feature)** — new functionality, cross-module, user-facing. Run phases 1-8.
- **B (bug)** — something broken. Run debug workflow D0-D6. See [debug.md](debug.md).

**Classify, announce type to user, proceed. If user disputes type, use their type.**

**Step 2.5 — Memory Context Sweep (MANDATORY).** Before any phase logic executes, load project context from MemPalace. Type S (simple) can skip.

**Step A — Refresh index (sequential, must complete first):**
```
mempalace_reconnect
```

**Step B — Extended sweep (ALL 8 in parallel, no dependencies):**

**Core context (existing 4):**
```
mempalace_diary_read agent_name="doit" last_n=5
mempalace_kg_query entity="<project>"
mempalace_kg_timeline entity="<project>"
mempalace_search query="<用户请求关键词>" wing="<project>" limit=5 max_distance=0.7
```

**Knowledge rooms (4):**
```
mempalace_search wing="<project>" room="knowledge_code" limit=3 max_distance=0.7
mempalace_search wing="<project>" room="knowledge_api" limit=3 max_distance=0.7
mempalace_search wing="<project>" room="knowledge_db" limit=3 max_distance=0.7
mempalace_search wing="<project>" room="knowledge_flow" limit=3 max_distance=0.7
```

**Sessions feedback (2, captures user feedback stored in sessions wing):**
```
mempalace_search wing="sessions" room="general" limit=3 max_distance=0.7
mempalace_search wing="sessions" room="problems" limit=3 max_distance=0.7
```
**Why:** `sessions/technical` (3500+ drawers) is auto-save noise — excluded. `sessions/general` and `sessions/problems` contain structured user feedback (auto-compact, no-repeated-actions, etc.) that applies across all projects.

**CRITICAL: `wing="<project>"` is mandatory on every `mempalace_search`.** The `sessions` wing (auto-save) typically contains 80-95% of all drawers. Searching without `wing` filter returns auto-saved session dumps, not project context. `<project>` = project root directory name.

**Type-specific sweep:**
- **Type F (feature):** All 8 calls above + sessions feedback 2 = 10 total
- **Type S (simple):** Only core 4 calls, skip knowledge rooms + sessions
- **Type B (bug):** Core 4 + sessions 2 + `mempalace_search wing="<project>" room="knowledge_code" limit=3 max_distance=0.7` + `mempalace_search query="<bug 关键词> error" wing="<project>" room="bugs" limit=5 max_distance=0.7`
- **Type R (resume):** Core 4 + sessions 2 + `mempalace_search query="<project> resume in-progress" wing="<project>" limit=3 max_distance=0.7`

**KG empty detection:** If `mempalace_kg_query` returns 0 relationships AND `mempalace_kg_timeline` returns empty, note `[WARN] KG empty — Phase 8 MUST populate it`. This means prior sessions failed to write KG facts.

**Search relevance gate (CRITICAL):** `mempalace_search` returns results even when similarity is near zero. After each search, check the `similarity` field:
- `similarity >= 0.3` → relevant, use the content
- `similarity < 0.3` → NOT relevant, treat as if empty (`[]`). Do NOT use the content, do NOT hallucinate that it's related.
- `results: []` (empty array) → no data, proceed without MP context

**Why:** A wing with skill docs (e.g., `myskill/skills`) will match any query with similarity ~0.0-0.1. The model sees "5 results returned" and assumes they are relevant — they are not. This causes the model to wait for MP context that doesn't exist, blocking the workflow.

**Per-call rule:** After processing MP search results, explicitly note:
- `[MP] <N> relevant results from <wing>/<room>` (if any result has similarity >= 0.3)
- `[MP-EMPTY] <wing>/<room> no relevant data` (if all results < 0.3 or empty array)

If MemPalace unavailable (any call errors) → skip all MP steps silently for this session. Filesystem remains primary.

**Before proceeding: check if user's prompt contains reference documentation.** If yes, capture it before any phase runs. See [doc-capture.md](doc-capture.md). Doc capture is independent of classification type (R/S/F/B) — always run first.

## Phase 1 — Spec (完整 grill 协议)

**Step 0.5 — Knowledge Injection (before grill):**

Before asking grill questions, inject relevant past knowledge to inform decisions:

**[LOAD] [learn/inject.md](learn/inject.md) — 搜索、排名、注入。**

1. Search for relevant past sessions using user's request as semantic query
2. Rank by relevance + time decay (recent sessions weighted higher)
3. Inject top-3 into context as `[LEARN] Related past sessions:`
4. Use injected knowledge to pre-fill grill options and warn about known pitfalls

If no knowledge found → proceed with standard grill. If knowledge tools unavailable → skip injection.

**Step 1: [LOAD:phase-1] grill-me → Grill FIRST (before writing any REQs):**
- `Skill skill="grill-me"` — 加载 grill 协议指令
- **Uncertainty scan:** List 3-5 things you're uncertain about in the user's request. Rate 1-5. Focus questions on items >= 3.
- Ask 5+ questions via AskUserQuestion (Type F) or 3+ (Type B). Each question must:
  - Reference a specific detail from the user's request
  - Explain WHY the answer matters (consequence of getting it wrong)
  - Provide 2-4 concrete options, each with: **named approach** + **`->` consequence** + **`Trade-off:`** + **`适合:` project fit**
  - Exactly one option marked `(Recommended)` with project-specific reason
- Internet search for existing solutions — Tavily MCP or WebSearch
- MP search for prior specs/knowledge — `mempalace_search wing="<project>"`
- Write grill summary to `.doit/grill-summary.json` (questions asked, checklist, answers)
- **Do NOT write any REQs until grill is complete.**

**Step 2: Write spec** — Split grill output into REQ-N items, save to `.spec/current.md`. See [spec.md](spec.md).

**铁律：Grill 最低 5 个问题(Type F) / 3 个(Type B)。** Phase 1 必须至少 5 个 grill 问题（通过 AskUserQuestion）。少于 5 个 = 未完成的 Phase 1 = 不能进入 Phase 2。

**Phase 1 完成后：** 记录工作日志（grill 问题数、用户回答、REQ 数量）。See [worklog.md](worklog.md)。

**[RELEASE:phase-1] grill-me** — grill 协议完成，释放 grill-me skill 上下文。执行 `ctx_compress` 压缩上下文窗口。

### Phase 1 → Phase 2 Gate

进入 Phase 2 前，自检：
1. 统计本会话 AskUserQuestion 调用次数 — 必须 >= 5 (Type F) 或 >= 3 (Type B) 个 grill 问题
2. 确认 GRILL CHECKLIST 全部完成（challenge, search, MP, alternatives, scope）
3. 确认 `.doit/grill-summary.json` 已写入
4. 如果任一检查失败，返回 Phase 1 补全缺失步骤

未通过自检 = Phase 1 未完成 = 不能进入 Phase 2。

## Phase 9.5 — Completion Summary + Knowledge Extraction

**Before Phase 10, tell the user what was done and what to do next.** This is the last visible output before session ends. See [commit.md](shared/commit.md) Gate section for format.

Must include:
- Branch, commit hash, change summary
- What each REQ delivered
- **Actionable next steps** — concrete commands to run, features to test, services to restart

**No vague "done" messages.** User needs to know: "what do I do now?"

### Knowledge Extraction (MANDATORY after completion summary)

**[CALL] Execute these MCP tool calls. No skip. No "if available" rationalization.**

**Step 1 — Gather data:**
```
[CALL] ctx_shell("git diff --stat HEAD~1..HEAD") — what files changed?
[CALL] ctx_shell("git log -1 --format='%s'") — commit message
```

**Step 2 — Extract knowledge items (execute ALL, even if empty):**
For each category, construct the knowledge entry from the session data:
```
[CALL] mempalace_check_duplicate content="<code patterns from this session>"
[CALL] mempalace_add_drawer wing="<project>" room="knowledge_code" content="<patterns>" source_file="<file>"
[CALL] mempalace_add_drawer wing="<project>" room="knowledge_api" content="<APIs discovered>"
[CALL] mempalace_add_drawer wing="<project>" room="knowledge_db" content="<DB changes>"
[CALL] mempalace_add_drawer wing="<project>" room="knowledge_flow" content="<architecture decisions>"
```

**Step 3 — KG facts:**
```
[CALL] mempalace_kg_add subject="<project>" predicate="shipped" object="<feature>" valid_from="<today>"
[CALL] mempalace_kg_stats — verify KG populated
```

**Step 4 — Announce:**
```
[KNOWLEDGE] Extracted N items (code: X, api: Y, db: Z, flow: W)
```

**If nothing to extract for a category:** Skip that category silently. But still run KG stats and announce.
**If ALL categories empty:** Announce `[KNOWLEDGE] No new knowledge this session` — don't skip the announcement.
**MP unavailable:** Fall back to `[CALL] ctx_shell("echo '<extraction>' > .doit/knowledge/<date>-<project>.json")` — filesystem backup.

## Phase 9.5.5 — Knowledge Distillation (结构化知识沉淀)

**[LOAD] [learn/extract.md](learn/extract.md) — 完整提取流程、用户确认、多层存储。**

**[CALL] Execute these MCP tool calls. No skip.**

1. **[CALL] Gather session data:**
```
[CALL] ctx_shell("git log -1 --format='%H %s'")
[CALL] ctx_shell("git diff --stat HEAD~1..HEAD")
[CALL] ctx_shell("cat .doit/worklog.json 2>/dev/null")
[CALL] ctx_shell("cat .spec/current.md 2>/dev/null")
[CALL] ctx_shell("cat .doit/grill-summary.json 2>/dev/null")
```

2. **[CALL] Generate knowledge record** — construct JSON per [learn/schema.json](learn/schema.json)

3. **[CALL] Storage (execute ALL):**
```
[CALL] mempalace_check_duplicate content="<summary>" — check duplicates
[CALL] mempalace_add_drawer wing="<project>" room="knowledge_distillation" content="<summary>"
[CALL] mempalace_kg_add subject="<project>" predicate="shipped" object="<feature>" valid_from="<today>"
```

4. **[CALL] Filesystem backup:**
```
[CALL] ctx_shell("mkdir -p .doit/knowledge && echo '<JSON>' > .doit/knowledge/<date>-<short-id>.json")
```

5. **Report:** `[KNOWLEDGE] Saved to: mempalace ✓, filesystem ✓`

**Failed session?** Still extract with `status: "failed"` + root cause. These teach what NOT to do.
**Layer fails?** Skip that layer, continue. Filesystem always available as final fallback.
**ALL layers fail:** `[WARN] Knowledge extraction failed — saved to .doit/knowledge/`

## Phase 10 — Session Summary

**[CALL] Execute ALL. Don't skip with "if available" rationalization.**

1. **[CALL] RTK token report:**
```
[CALL] ctx_shell("rtk gain") — total session token savings
[CALL] ctx_shell("rtk gain --history") — per-command savings breakdown
```
RTK unavailable → `[WARN] RTK not installed` and continue.

2. **[CALL] Context-Mode stats:**
```
[CALL] ctx stats — log session token savings
```

3. **[CALL] Headroom compression:**
```
[CALL] headroom_stats (MCP tool) — show compression statistics for session
```

4. **[CALL] MemPalace KG + diary:**
```
[CALL] mempalace_diary_write agent_name="doit" entry="<compact session summary>" topic="worklog"
[CALL] mempalace_memories_filed_away — verify auto-save checkpoint
[CALL] mempalace_kg_stats — verify KG populated
```
**If KG still 0 entities → add facts NOW:**
```
[CALL] mempalace_kg_add subject="<project>" predicate="shipped" object="<feature>" valid_from="<today>"
```
```
[CALL] mempalace_kg_timeline entity="<project>" — log project timeline
```

6. **[CALL] Caveman compress:** Run `/caveman:compress CLAUDE.md` to compress CLAUDE.md.

**This phase always runs last.** It gathers session statistics and preserves knowledge for future sessions.
**MANDATORY: End with `/compact` to compress conversation context.**

**⚠️ Compact 副作用：** `/compact` 压缩上下文后，TaskUpdate 的 `taskId` 会丢失。如果 compact 后遇到 `InputValidationError: taskId is missing`，参见 [errors.md](errors.md)#compact-后-task-丢失。

## Resume — Cross-Session Recovery

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

## Phase Gate Checklist

**After completing ANY phase, run this checklist before ending your response.** The conversation may continue, but the workflow MUST complete all phases. Code changes alone are NEVER the end of a doit session.

```
[Phase Gate] Type R flow (resume):
  [x] Phase 0     Classify → detect in-progress work
  [x] Resume from detected phase → complete remaining phases
  [x] Phase 9.5     Completion Summary (user-facing)
  [x] Phase 9.5.5   Knowledge Distillation (structured extraction)
  [x] Phase 10      Session Summary

[Phase Gate] Type F flow (full):
  [x] Phase -1    Detect Environment + Config
  [x] Phase 0     Classify Request
  [x] Phase 1     Spec
  [x] Phase 1a      Grill: skill loaded, 5+ questions (Type F) / 3+ (Type B), checklist done, .doit/grill-summary.json
  [x] Phase 1b      Spec: .spec/current.md written, branch created
  [x] Phase 2     Plan (impact analysis)
  [x] Phase 3     Execute (TDD per REQ)
  [x] Phase 4     E2E (initial tests)
  [x] Phase 5     Review
  [x] Phase 6     Review + Simplify
  [x] Phase 7     E2E Verification Loop
  [x] Phase 8     Commit + Push
  [x] Phase 9       Cleanup intermediate files
  [x] Phase 9.5     Completion Summary (user-facing)
  [x] Phase 9.5.5   Knowledge Distillation (structured extraction)
  [x] Phase 10      Session Summary
  [x] Doc Capture (if user prompt has docs)

[Phase Gate] Type S flow (simple):
  [x] Phase 0   Classify
  [~] Phase -1  Skip (use env-cache.json if available, otherwise skip)
  [x] Execute directly
  [x] Phase 9.5     Completion Summary (user-facing)
  [x] Phase 9.5.5   Knowledge Distillation (structured extraction)
  [x] Phase 10      Session Summary
  [x] Doc Capture (if user prompt has docs)

[Phase Gate] Type B flow (bug):
  [x] Phase 0   Classify
  [x] D0-D6     Debug workflow (debug.md)
  [x] Phase 8     Commit + Push
  [x] Phase 9.5   Completion Summary (user-facing)
  [x] Phase 9.5.5 Knowledge Distillation (structured extraction)
  [x] Phase 10    Session Summary
```

**After Phase 3 completes:** always continue to Phase 4. Never stop at "tests pass, done."
**After Phase 6 completes:** always continue to Phase 7. E2E verification after simplification.
**After Phase 7 completes:** always continue to Phase 8. Every feature ships committed + pushed.
**After Phase 8 completes:** always continue to Phase 9. Clean up intermediate files.
**After Phase 9 completes:** always continue to Phase 9.5. Present completion summary to user.
**After Phase 9.5 completes:** always continue to Phase 9.5.5. Extract structured knowledge.
**After Phase 9.5.5 completes:** always continue to Phase 10. Gather session statistics and preserve knowledge.

**The only valid end state is Phase 10 complete.** If you're about to say "done" or "completed" and Phase 10 has not run, you haven't finished.
