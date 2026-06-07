# Phase Details — 按需加载

**本文件包含 Phase 的详细执行步骤。SKILL.md 仅保留索引 + [LOAD] 指令。执行对应 phase 前，模型必须读取本节。**

## Phase 0 — Classify Request (完整流程)

**Step 0 — Sync with remote (MANDATORY, before anything else).** If the project has a git remote, pull latest:
```bash
if git remote 2>/dev/null | grep -q .; then
  git pull --rebase 2>/dev/null || git pull 2>/dev/null || true
fi
```
**Why:** avoids working on stale code, prevents conflicts. `|| true` so network errors don't block.

**Step 1 — Load doit + caveman + grill-me skills for the entire session.** Call the Skill tool to load all three. These are Tool calls, not code comments:

```
Skill skill="doit"
Skill skill="caveman"
Skill skill="grill-me"
```

If caveman skill is not found, announce `[WARN] caveman not installed -> verbose mode` and continue.
If grill-me skill is not found, announce `[WARN] grill-me not installed -> basic grill mode` and continue. **grill-me is required for Phase 1 grill protocol.** Without it, the model only has a 3-line reminder to "grill" — which it tends to skip.
CLAUDE.md `## Skill Loading` section (written by Phase -1) also enforces this, so even if this step is skipped, the CLAUDE.md instruction should trigger skill load.

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

**Step B — Extended sweep (ALL 8 in parallel, no dependencies):**

**Core context (existing 4):**
```
mempalace_diary_read agent_name="doit" last_n=5
mempalace_kg_query entity="<project>"
mempalace_kg_timeline entity="<project>"
mempalace_search query="<用户请求关键词>" wing="<project>" limit=5
```

**Knowledge rooms (4):**
```
mempalace_search wing="<project>" room="knowledge_code" limit=3
mempalace_search wing="<project>" room="knowledge_api" limit=3
mempalace_search wing="<project>" room="knowledge_db" limit=3
mempalace_search wing="<project>" room="knowledge_flow" limit=3
```

**Sessions feedback (2, captures user feedback stored in sessions wing):**
```
mempalace_search wing="sessions" room="general" limit=3
mempalace_search wing="sessions" room="problems" limit=3
```
**Why:** `sessions/technical` (3500+ drawers) is auto-save noise — excluded. `sessions/general` and `sessions/problems` contain structured user feedback (auto-compact, no-repeated-actions, etc.) that applies across all projects.

**CRITICAL: `wing="<project>"` is mandatory on every `mempalace_search`.** The `sessions` wing (auto-save) typically contains 80-95% of all drawers. Searching without `wing` filter returns auto-saved session dumps, not project context. `<project>` = project root directory name.

**Type-specific sweep:**
- **Type F (feature):** All 8 calls above + sessions feedback 2 = 10 total
- **Type S (simple):** Only core 4 calls, skip knowledge rooms + sessions
- **Type B (bug):** Core 4 + sessions 2 + `mempalace_search wing="<project>" room="knowledge_code" limit=3` + `mempalace_search query="<bug 关键词> error" wing="<project>" room="bugs" limit=5`
- **Type R (resume):** Core 4 + sessions 2 + `mempalace_search query="<project> resume in-progress" wing="<project>" limit=3`

**KG empty detection:** If `mempalace_kg_query` returns 0 relationships AND `mempalace_kg_timeline` returns empty, note `[WARN] KG empty — Phase 8 MUST populate it`. This means prior sessions failed to write KG facts.

If MemPalace unavailable (any call errors) → skip all MP steps silently for this session. Filesystem remains primary.

**Before proceeding: check if user's prompt contains reference documentation.** If yes, capture it before any phase runs. See [doc-capture.md](doc-capture.md). Doc capture is independent of classification type (R/S/F/B) — always run first.

## Phase 1 — Spec (完整 grill 协议)

**Step 1: Grill FIRST (before writing any REQs):**
- Load grill-me skill: `Skill skill="grill-me"`
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

After presenting the completion summary, extract reusable knowledge from this session into MemPalace. This is NOT optional.

**Extraction checklist:**
- [ ] Code patterns written this session -> `knowledge_code`
- [ ] APIs discovered/used -> `knowledge_api`
- [ ] DB schemas created/modified -> `knowledge_db`
- [ ] Data flows/architecture decisions -> `knowledge_flow`

**Process:**
1. Review `git diff --stat` — what code was written?
2. Scan conversation for API discussions, DB schemas, architecture decisions
3. For each knowledge item found: `mempalace_check_duplicate` -> `mempalace_add_drawer`
4. Announce: `[KNOWLEDGE] Extracted N items (code: X, api: Y, db: Z, flow: W)`

**Knowledge entry format:**
```
mempalace_add_drawer wing="<project>" room="knowledge_code" content="<structured summary, 2-5 lines>" source_file="<file path>"
```

**KG facts for extracted knowledge (if applicable):**
```
mempalace_kg_add subject="<project>" predicate="has_api" object="<api name>" valid_from="<today>"
mempalace_kg_add subject="<project>" predicate="has_db" object="<db schema>" valid_from="<today>"
```

**If nothing extracted:** Announce `[KNOWLEDGE] No new knowledge to extract this session` — don't skip silently.
**MP unavailable:** Skip silently. Filesystem remains primary.

## Phase 10 — Session Summary

After Phase 9.5 completion summary, gather session statistics and preserve knowledge:

1. **RTK token report** (if available):
   - `rtk gain` — show total session token savings
   - `rtk gain --history` — per-command savings breakdown
2. **Context-Mode stats** (if available): `ctx stats` — log session token savings
3. **Headroom compression** (if available):
   - `headroom memory add --content "<session summary>" --scope SESSION` — save compressed session to headroom memory
   - `headroom memory stats` — verify memory was saved
   - If headroom proxy was running: `headroom proxy stats` — show token savings from proxy compression
4. **MemPalace diary** (if available):
   - `mempalace_diary_write agent_name="doit" entry="<compact summary>" topic="compact"`
   - `mempalace_memories_filed_away` → verify auto-save checkpoint was saved
   - `mempalace_kg_stats` → verify KG was populated. If still 0 entities after Phase 8, add facts NOW:
     - `mempalace_kg_add subject="<project>" predicate="shipped" object="<feature>" valid_from="<today>"`
   - `mempalace_kg_timeline entity="<project>"` → log project timeline for future reference
5. **Caveman compress** (if available): Run `/caveman:compress CLAUDE.md` to compress CLAUDE.md using caveman's built-in compression skill.

**This phase always runs last.** It gathers session statistics and preserves knowledge for future sessions.

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
  [x] Phase 9.5   Completion Summary (user-facing)
  [x] Phase 10    Session Summary

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
  [x] Phase 9     Cleanup intermediate files
  [x] Phase 9.5   Completion Summary (user-facing)
  [x] Phase 10    Session Summary
  [x] Doc Capture (if user prompt has docs)

[Phase Gate] Type S flow (simple):
  [x] Phase 0   Classify
  [x] Execute directly
  [x] Phase 9.5 Completion Summary (user-facing)
  [x] Phase 10  Session Summary
  [x] Doc Capture (if user prompt has docs)

[Phase Gate] Type B flow (bug):
  [x] Phase 0   Classify
  [x] D0-D6     Debug workflow (debug.md)
  [x] Phase 8   Commit + Push
  [x] Phase 9.5 Completion Summary (user-facing)
  [x] Phase 10  Session Summary
```

**After Phase 3 completes:** always continue to Phase 4. Never stop at "tests pass, done."
**After Phase 6 completes:** always continue to Phase 7. E2E verification after simplification.
**After Phase 7 completes:** always continue to Phase 8. Every feature ships committed + pushed.
**After Phase 8 completes:** always continue to Phase 9. Clean up intermediate files.
**After Phase 9 completes:** always continue to Phase 9.5. Present completion summary to user.
**After Phase 9.5 completes:** always continue to Phase 10. Gather session statistics and preserve knowledge.

**The only valid end state is Phase 10 complete.** If you're about to say "done" or "completed" and Phase 10 has not run, you haven't finished.
