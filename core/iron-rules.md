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

## 铁律 — Active Task Management (活跃任务管理)

**任务不是创建完就放着。** 每个子步骤完成后立即更新任务状态。

**子步骤定义**：一个独立的、可识别的操作单元。例如：
- 读一个文件理解上下文 → 1 个子步骤
- 执行一次搜索 → 1  个子步骤
- 完成一个 REQ 的实现 → 1 个子步骤
- 运行一次测试 → 1 个子步骤

**频率要求**：
- 开始子步骤 → 先标记 `in_progress`
- 完成子步骤 → 立即标记 `completed`
- **最多 3 个子步骤不允许有 task 状态更新** —— 超过 = 违反铁律
- Phase 边界是最低要求，不是唯一要求。子步骤之间也要更新。

**CLI 适配**（通过 `[[TASK:*]]` 抽象操作自动适配）：
- Claude Code → `TaskCreate` / `TaskUpdate`
- OpenCode → `todowrite`
- oh-my-pi → 编辑 `.doit/tasks.md`
- Codex → 编辑 `.doit/tasks.md`

**为什么**：不活跃的任务管理会导致系统警告（"task tools haven't been used recently"），浪费上下文空间。更重要的是，不跟踪进度 = 不知道自己在哪 = 容易重复执行或遗漏步骤。

**铁律：任务列表是进度跟踪工具，不是装饰。活跃使用，不是创建完就放着。**

**Stale Task 清理：** 在 Phase 0 创建新任务列表前，必须先调用 `[[TASK:list]]` 清理旧工作流残留的任务。不清理 = 任务列表混乱 = 模型无法判断当前工作流进度。

## 铁律 — Phase -1 不可跳过

**Phase -1 (环境检测) 是绝对强制入口，必须先于 Phase 0 (分类) 完成。**

模型首先应该对环境有个快速清晰的认知：
- 编码环境（语言、运行时、版本）
- CLI 环境（Claude Code / OpenCode / Codex / oh-my-pi / MiMo）
- bash 环境（shell、工具可用性）
- code 环境（git status、branch、recent commits）
- agent 环境（MCP tools、skills、memory layers）
- 上下文（session memory、MemPalace、prior findings）

**不完成 Phase -1 就进入 Phase 0 = 盲分类 = 可能选错工作流。**

Phase -1 有缓存机制：如果 `.doit/env-cache.json` 存在且 <24h 且 `.git/HEAD` 未变，可以快速使用缓存值。但这仍然是必须执行的步骤，只是可以快速完成。

## 铁律 — 完整工作流不可跳过

Phase -1 → 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 9.5 → 9.5.5 → 10

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
Understand the problem before writing code. Use codegraph_context to explore.

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
