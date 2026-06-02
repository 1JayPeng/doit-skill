# Coding Principles

Seven principles that guide every phase of the doit workflow. Three iron rules first:

## 0. Non-Interruptive Questions (铁律)

**Never stop the conversation to ask the user a question. Always use AskUserQuestion.**

Old pattern: print question -> stop -> wait for user input. This blocks the workflow, wastes tokens, and frustrates the user.
New pattern: call `AskUserQuestion` with 2-4 options. User answers without interrupting the flow. Agent continues executing.

- Never write "which do you choose?" then stop and wait
- Never write "Wait for user input" then pause
- Always use `AskUserQuestion` with clear options
- Always provide a sensible default as the first option
- If user doesn't answer -> proceed with default

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
- **10s–5min** → `Bash run_in_background=true` OR shell `&` + log file + `[START]`/`[END]` markers
- **>5min** → tmux named session + Monitor + auto-continuation
- **No background mechanism** → `ScheduleWakeup` to poll periodically

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
