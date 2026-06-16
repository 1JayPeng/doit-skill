# Iron Rules — 铁律 (Tool-Agnostic)

## 铁律 — Non-Interruptive Questions

**Non-Interruptive Questions are NOT user questions.** They are self-verification questions the agent asks itself during execution. They MUST NOT pause the workflow.

**Non-Interruptive Question Pattern:**
- "Are all REQs complete?" → Check spec alignment, don't ask user
- "Should I run tests?" → YES, run tests, don't ask user
- "Is this the right approach?" → Check Phase 2 plan, don't ask user
- "Did I follow TDD?" → Check RED/GREEN cycle, don't ask user

**When to use `[[USER:ask]]`:**
- User input required for design decisions
- Scope clarification (only when spec is ambiguous)
- Confirmation of dangerous operations (data deletion, force pushes)
- User preference (e.g., "Should I use X or Y?")

**When NOT to use `[[USER:ask]]`:**
- Self-verification questions
- Workflow progression questions
- Questions answerable by reading existing docs/spec
- Questions about whether to follow iron rules (answer is always YES)

## 铁律 — Background Execution

**铁律：永远不要空等长时间任务。**

运行任何命令前，估计执行时间：
- **<10s** → Foreground `[[SHELL:run]]` (OK)
- **≥10s** → **MUST** background `[[SHELL:run command="..." background=true]]`
- **≥5min** → **MUST** use tmux + Monitor or `/loop` polling

**执行规则:**
1. Estimate runtime first
2. Ensure output readability — background tasks write to files
3. Clear exit signal — completion indicator (exit code, log line)
4. Mandatory polling — every background task MUST have monitoring
5. Continue working — after launching background task, continue with other work

## 铁律 — Commit + Push Mandatory

**铁律：每个 phase 完成后必须 commit + push。**

```
[[SHELL:run command="git add -A && git commit -m 'type: description' && git push"]]
```

If no changes → skip silently.

**Commit message format:**
```
type: short description

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

| Type | Usage |
|------|-------|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Code restructure |
| `docs` | Documentation |
| `test` | Test changes |
| `chore` | Build/CI/deps |

## 铁律 — MemPalace 读写对称

If MemPalace is available:
- **Read before write:** `mempalace_search` for relevant context before starting work
- **Write after work:** `mempalace_add_drawer` to store implementation notes, decisions, patterns

If MemPalace unavailable → skip silently. Filesystem remains primary.

## 铁律 — 完整工作流不可跳过

Phase 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 9.5 → 9.5.5 → 10

**跳过 = 工作流未完成。** Type Q/S/B have abbreviated flows defined in Phase 0 classifier.

## 铁律 — Review + Simplify 不可跳过

Phase 6 (Review + Simplify) is MANDATORY. Cannot skip. Even if Phase 5 (Review) found nothing, Phase 6 must still run.

## 铁律 — 危险操作保护

**涉及数据或代码删除的操作，必须先通过 `[[USER:ask]]` 确认。**

- Database DROP/TRUNCATE/DELETE without WHERE
- `rm -rf` / `rm -r` / `rm -f`
- `git push --force` / `git reset --hard` / `git clean -f`

## 铁律 — 减少暂停对话

**减少不必要的 `[[USER:ask]]` 调用。** Batch multiple questions into one `[[USER:ask]]` call when possible.

## 铁律 — 不重复相同操作

**Never repeat the same tool call without progress.** If Read/Search/Shell returns the same result, don't call it again with the same parameters.

## 通用编码原则

### Think Before Coding
Understand the problem before writing code. Use tokensave_context/codegraph_context to explore.

### Brevity First
Short, focused code. No unnecessary abstractions. Three identical lines > premature abstraction.

### Surgical Edits
Only modify files identified by the plan. No drive-by refactoring.

### Goal-Driven Execution
Every code change must serve the current REQ. No feature creep.

## 铁律 — ctx_read 高级模式选择策略

| Goal | Mode | When |
|------|------|------|
| Edit this file | `full` | Before any edit |
| Re-read after edit | `diff` | Post-edit verification |
| Large file overview | `map` | >500 lines, won't edit |
| Specific region | `lines:N-M` | Know exact location |
| Unsure | `auto` | System selects |

## 铁律 — 无命令不调用 Shell

**Never call `[[SHELL:run]]` without a command.** The command must be explicitly specified.

## 铁律 — InputValidationError 路由

When `InputValidationError` occurs:
1. Check [errors.md](../errors.md) for known fixes
2. If tool params wrong → re-read tool docs
3. Don't retry same call that just failed
