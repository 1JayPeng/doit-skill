# Coding Principles

Ten principles that guide every phase of the doit workflow. Seven iron rules first:

## 0. Non-Interruptive Questions (铁律)

**Never stop the conversation to ask the user a question. Always use AskUserQuestion.**

Old pattern: print question -> stop -> wait for user input. This blocks the workflow, wastes tokens, and frustrates the user.
New pattern: call `AskUserQuestion` with 2-4 options. User answers without interrupting the flow. Agent continues executing.

- Never write "which do you choose?" then stop and wait
- Never write "Wait for user input" then pause
- Always use `AskUserQuestion` with clear options
- Always provide a sensible default as the first option
- If user doesn't answer -> proceed with default
- **Exception: grill questions.** Grill questions must be asked first, then defaults apply if user doesn't answer. Skipping grill != user not answering.

### Applied Everywhere

- **Phase -1 (Env Detection)** — env conflict -> AskUserQuestion with detected envs as options
- **Phase 1 (Spec)** — grill -> AskUserQuestion for each clarification
- **Phase 3 (Execute)** — spec alignment -> AskUserQuestion "Proceed to next REQ?"
- **Phase 4 (E2E)** — L2/L3 HITL -> AskUserQuestion "Which combo needs testing?"
- **Debug (D0)** — reproduction steps unclear -> AskUserQuestion

## 0.5. Long-Running Tasks Must Be Polled (铁律)

**Never wait idle for a long-running command. Always launch in background, set up polling, and continue working.**

Old pattern: run `cargo build --release` in Bash, sit idle for 5 min. Wastes time, blocks workflow, user stares at frozen agent.
New pattern: launch in background -> set up completion signal -> do other work -> auto-resume when notified.

- **<10s** → direct Bash call (foreground OK)
- **10s–30min** → shell `&` + log file + `/loop` directive (recommended) + ScheduleWakeup
- **>30min** → tmux named session + Monitor + auto-continuation

- **Always set up a completion signal** — `[END]` marker in log, Monitor check, or ScheduleWakeup callback
- **Never say "waiting for X..." then go silent** — poll or do other work
- **Never let a long task block the workflow** — if build takes 3 min, use that time to prepare tests, read docs, or plan next phase

This is not a suggestion. It is an iron rule. If a command takes longer than a coffee break, it runs in the background and Claude Code polls it.

### Applied Everywhere

- **Phase 3 (Execute)** — `cargo build --release`, `cargo test --all`, long test suites -> background
- **Phase 4 (E2E)** — dev server + test suite -> tmux + monitor
- **Phase 7 (E2E Verify)** — re-run full e2e after simplify -> background + monitor
- **Phase 8 (Commit + Push)** — large repo push -> background with log
- **Any phase** — docker build, database migration, large file processing -> background tier matching duration

See [background-process.md](background-process.md) for full three-tier patterns.

## 1. Commit + Push Mandatory (铁律)

**Every code change MUST be committed and pushed. No exceptions.**

Old pattern: implement feature -> "done" -> no commit. Work lost on session end, no git history, no PR trail.
New pattern: implement -> commit with meaningful message -> push to remote -> "done".

- **Always commit after Phase 3, 4, 5, 6, 7** — intermediate commits for safety
- **Final commit after Phase 8** — meaningful message matching project's commit style
- **Push to remote** — `branch` (default), `current`, or `none` (only if user explicitly requests no push)
- **Never say "done" without committing** — uncommitted work is lost work
- **Never skip push** — local commits don't protect against session loss

This is not optional. Code without commit is just text in a buffer. Code without push is local only. Both are fragile.

### Applied Everywhere

- **Phase 3 (Execute)** — commit after each REQ completes (intermediate safety)
- **Phase 8 (Commit + Push)** — final commit with full message, push to remote
- **Debug (D6)** — commit fix + regression test, push to remote
- **Any code change** — commit before compacting context

See [commit.md](commit.md) for commit message conventions and push strategies.

## 1.25. MemPalace Read-Write Symmetry (铁律)

**MemPalace calls are the same level as TokenSave — mandatory when available, silently skip when not.**

- **Phase 0 sweep must execute** (Type S excepted) — 4 parallel calls load project context
- **`[MP-READ]` marked steps** — read project history (specs, decisions, implementations, bugs) for current phase context
- **`[MP-WRITE]` marked steps** — write phase output (specs, ADRs, implementation summaries, KG facts, diary)
- **Read before write** — Phase 0 does global sweep, per-phase `[MP-READ]` does targeted search, `[MP-WRITE]` after phase completes
- **MP unavailable** → any call errors → silently skip all MP steps for this session, filesystem remains primary

## 1.5. Complete Workflow Cannot Be Skipped (铁律)

**The workflow is not a suggestion, it is an iron rule. Every phase must be completed in order. No skipping.**

Old pattern: modify code -> "done" -> skip Review/Simplify/E2E -> commit directly. This leads to degraded quality, duplicated logic, over-engineering, and bugs shipped to production.
New pattern: every phase completed in order -> Phase Gate check -> next phase.

**Forbidden behaviors:**
- **禁止**跳过 Phase 1 (Spec) 直接写代码 — 没有 spec 不写代码
- **禁止**跳过 Phase 4 (E2E) 直接进入审查 — 没有 E2E 不审查
- **禁止**跳过 Phase 5-6 (Review + Simplify) 直接提交 — 没有审查不提交
- **禁止**跳过 Phase 7 (E2E 验证) 直接提交 — 简化后必须重新验证
- **禁止**跳过 Phase 8 (Commit + Push) 说"完成" — 未提交等于丢失
- **禁止**跳过 Phase 10 (Compact) 结束对话 — 不压缩上下文

**Phase completion means continue immediately:**
- Phase 3 done → Phase 4, no stop
- Phase 4 done → Phase 5, no stop
- Phase 5 done → Phase 6, no stop
- Phase 6 done → Phase 7, no stop
- Phase 7 done → Phase 8, no stop
- Phase 8 done → Phase 9, no stop
- Phase 9 done → Phase 9.5, no stop
- Phase 9.5 done → Phase 10, no stop

**The only valid end state is Phase 10 compact.**

### Applied Everywhere

- **Type F (Feature)**: Full pipeline -1 through 10, every phase
- **Type S (Simple)**: Phase 0 → execute → Phase 9.5 → Phase 10. Still needs commit + compact.
- **Type B (Bug)**: Phase 0 → D0-D6 → Phase 8 → Phase 9.5 → Phase 10

## 1.6. Grill Enforcement (铁律)

**Phase 1 MUST grill the user's idea with minimum 5 questions (Type F) or 3 questions (Type B) before writing any REQs. Less than minimum = incomplete Phase 1 = cannot proceed to Phase 2.**

Old pattern: user says "I want X" -> agent immediately writes REQs. This produces specs that miss edge cases, don't challenge assumptions, and lead to wrong implementations.
New pattern: user says "I want X" -> agent grills with 5+ questions -> writes REQs informed by grill.

**Grill quality > quantity.** 5 specific questions that reference the user's request beat 12 generic questions. Each question must:
- Reference a specific detail from the user's request
- Explain WHY the answer matters (consequence of getting it wrong)
- Provide 2-4 concrete options, each with consequence + trade-off + project fit

**Option quality is mandatory, not optional:**
- **Bad:** `label: "Redis", description: "Fast caching"` — vague, no context
- **Good:** `label: "Redis cache (Recommended)", description: "In-memory -> sub-ms read. Trade-off: needs Redis infra. 适合: 高读低写场景。"`
- Each option: **named approach** + **`->` consequence** + **`Trade-off:`** + **`适合:` project fit**
- Exactly one `(Recommended)` with project-specific justification

**GRILL CHECKLIST — all must complete before writing REQs:**
- [ ] Challenge assumptions — at least 1 question
- [ ] Internet search for existing solutions — Tavily MCP or WebSearch
- [ ] MP search for prior specs/knowledge — `mempalace_search wing="<project>"`
- [ ] Alternative approaches — at least 1 question
- [ ] Scope clarification — at least 1 question

**All grill questions MUST use AskUserQuestion.** Never stop and wait.

### Applied Everywhere

- **Phase 1 (Spec)** — 3+ grill questions before any REQ written
- **Type F (Feature)** — full grill checklist
- **Type B (Bug)** — grill reproduction steps + scope

## 1.65. Dangerous Operations Protection (铁律)

**Any operation that deletes data or code must be confirmed via AskUserQuestion before execution.**

**What counts as dangerous:**
- **Database:** `DROP TABLE`, `TRUNCATE`, `DELETE`/`UPDATE` without `WHERE`
- **Filesystem:** `rm -rf`, `rm -r`, `rm -f`
- **Git:** `push --force`, `reset --hard`, `clean -f`
- **Code:** deleting source files with business logic

**Subagents inherit this rule.** The subagent prompt must include this iron rule.

See [dangerous-ops.md](dangerous-ops.md) for full patterns and hook configuration.

## 1.7. Review + Simplify Cannot Be Skipped (铁律)

**After every code change, Review (Phase 5) and Simplify (Phase 6) are mandatory. Unreviewed code cannot be committed.**

Old pattern: modify files -> commit directly. This leads to duplicated code, over-abstraction, undiscovered bugs, and out-of-sync documentation.
New pattern: code change → Review (find duplication, security issues, architecture problems) → Simplify (remove redundancy, flatten) → E2E verify → commit.

**Review must check:**
- Duplicated code (same logic appearing multiple times)
- Security vulnerabilities (OWASP Top 10: injection, XSS, auth bypass)
- Over-abstraction (3 layers of functions for one operation)
- Dead code (unused functions, variables, imports)
- README synchronization

**Simplify must execute:**
- Merge duplicated logic
- Delete dead code
- Flatten unnecessary abstraction layers
- Simplify error handling (only handle scenarios that can actually happen)
- Reduce line count (200 lines → 50 lines if possible)

### Forbidden Behaviors

- **禁止**跳过 Review 直接 commit
- **禁止**跳过 Simplify 直接提交 — "do it later" = never
- **禁止**perfunctory Review ("looks good") — must find specific issues
- **禁止**Simplify 后不重新运行 E2E (Phase 7) — simplification can break functionality

## 1.75. Token Optimization Tools (铁律)

**Always use token optimization tools. RTK (auto), lean-ctx (file ops), headroom (large output).**

Old pattern: `Read` a file -> 500 tokens. `Read` again -> 500 tokens. `Bash git status` -> 300 tokens. Total wasted: thousands per session.
New pattern: `ctx_read` -> first time full, subsequent ~13 tokens. `rtk git status` -> 50 tokens. `headroom_compress` -> 70-90% reduction.

- **Bash commands** → RTK auto-wraps via PreToolUse hook (no action needed)
- **Read file** → `ctx_read(path, mode)` (cached, repeated reads ~13 tokens)
- **Search code** → `ctx_search(pattern, path)` (60% less output than Grep)
- **List directory** → `ctx_tree(path, depth)` (80% less output than ls)
- **Large tool output (>500 lines)** → `headroom_compress(output)` → process summary, `headroom_retrieve(hash)` for details

This is not optional. Token optimization is a first-class concern. Every session should save 20-40% tokens through these tools.

### Applied Everywhere

- **Phase 3 (Execute)** — ctx_read for file reads, ctx_search for code search, headroom for large test output
- **Phase 5-6 (Review)** — ctx_read for reviewing changes, headroom for complexity reports
- **Phase 10 (Summary)** — rtk gain, ctx_stats, headroom_stats for session token report

## 2. Think Before Coding

**Don't assume. Don't hide confusion. Present trade-offs.**

LLMs often pick an interpretation silently and execute. This principle forces explicit reasoning:

- **State assumptions explicitly** — if unsure, ask instead of guessing
- **Present multiple interpretations** — when ambiguous, don't pick silently
- **Push back** — if there's a simpler approach, say so
- **Stop when confused** — point out what's unclear and request clarification

### Applied in Workflow

- **Phase 1 (Spec)** — grill the idea, challenge assumptions, present alternatives before writing REQs
- **Phase 2 (Plan)** — explore multiple implementation paths, pick simplest that satisfies all REQs
- **Phase 0 (Classify)** — if request type is unclear, ask user, don't guess

## 3. Brevity First

**Solve the problem with the least code. Don't over-speculate.**

Counter the tendency toward over-engineering:

- Don't add features beyond what's requested
- Don't create abstractions for one-shot code
- Don't add unrequested "flexibility" or "configurability"
- Don't add error handling for impossible scenarios
- If 200 lines can be 50, rewrite it

**Test:** Would a senior engineer think this is too complex? If yes, simplify.

### Applied in Workflow

- **Phase 3 (Execute)** — implement each REQ minimally, no extra functionality
- **Phase 6 (Review + Simplify)** — merge redundant code, remove dead imports, flatten unnecessary abstractions
- **Phase 5 (Review)** — eliminate duplication across the codebase

## 4. Surgical Edits

**Only touch what must be touched. Only clean up messes you created.**

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting
- Don't refactor things that aren't broken
- Match existing style, even if you prefer a different one
- If you notice unrelated dead code, mention it — don't delete it

When your changes create orphan code:

- Remove imports/variables/functions that became unused because of your changes
- Don't remove pre-existing dead code unless asked

**Test:** Every line changed should be directly traceable to the user's request.

### Applied in Workflow

- **Phase 3 (Execute)** — only modify files identified in Phase 2 plan
- **Phase 6 (Review + Simplify)** — cleanup limited to code introduced in this workflow run
- **Debug (D2 Fix)** — minimum change to make regression test pass, no unrelated fixes

## 5. Goal-Driven Execution

**Define success criteria. Loop verify until achieved.**

Transform imperative tasks into verifiable goals:

| Don't do... | Transform to... |
|-------------|-----------------|
| "Add validation" | "Write tests for invalid input, then make them pass" |
| "Fix the bug" | "Write a test that reproduces the bug, then make it pass" |
| "Refactor X" | "Ensure tests pass both before and after refactor" |

For multi-step tasks, state a brief plan:

```
1. [step] → verify: [check]
2. [step] → verify: [check]
3. [step] → verify: [check]
```

Strong success criteria let agents loop independently. Weak criteria ("make it work") require constant clarification.

### Applied in Workflow

- **Phase 3 (Execute)** — each REQ is a goal with testable verification (RED → GREEN)
- **Phase 4 (E2E)** — real assertions on exit code, stdout, file output, database state
- **Phase 7 (E2E Verify)** — compare actual output against spec REQs, not test assertions
- **Debug (D1)** — regression test must fail (RED) before fix is written
