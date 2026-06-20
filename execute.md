# Phase 3: Execute

## Rules

- **uv virtualenv for all Python code.** Create/activate with `uv venv` + `source .venv/bin/activate`. Every Python command runs through uv.
  - **Fallback:** If uv not available -> use `pip` + `python3 -m venv .venv` + `source .venv/bin/activate`.
- **RTK for all shell commands.** RTK auto-wraps via PreToolUse hook. All shell commands in this phase go through RTK for 60-90% token savings.
  - `rtk gain` — token savings analytics (run after Phase 3 completes)
  - `rtk gain --history` — command history with per-command savings
  - `rtk discover` — scan conversation history for missed optimization opportunities (run in Phase 6)
  - `rtk proxy <cmd>` — bypass RTK filter (debug only)
  - **Fallback:** If RTK not available -> run Bash commands directly (no token optimization).
- **RTK wraps all phases.** RTK is not Phase 3 only — it auto-wraps every Bash call via PreToolUse hook across the entire session.

- **lean-ctx for file operations.** Cache + compression for reads, searches, directory listings. **优先使用 lean-ctx，而非原生工具。**
  - `ctx_read(path, mode)` — 读文件（缓存，重复读取 ~13 token）
  - `ctx_multi_read(paths, mode)` — 批量读取多文件（一次调用替代 N 次，~3000 token 节省）
  - `ctx_search(pattern, path)` — 搜索代码（比 Grep 输出小 60%）
  - `ctx_tree(path, depth)` — 列目录（比 ls 输出小 80%）
  - `ctx_shell(command)` — 执行命令（95+ 压缩模式）
  - `ctx_delta(path)` — 增量 diff（仅返回变化行，~98% 节省，替代 ctx_read diff）
  - `ctx_refactor(action, path, line)` — LSP 重构（rename, references, definition）
  - `ctx_semantic_search(query)` — 语义代码搜索（概念级查找）
  - `ctx_url_read(url, mode)` — 网页/PDF/YouTube 压缩上下文
  - **Fallback:** If lean-ctx not available -> native Read/Grep/Bash tools

- **Context-Mode for context management.** Auto-indexes command output, provides semantic search.
- **Shell execution priority:** lean-ctx `ctx_shell` (compressed, fast) → Context-Mode `ctx_execute` (indexed, searchable) → native Bash. Prefer lean-ctx for simple commands, Context-Mode when you need to search output later.
- **Tool source annotation:** lean-ctx `ctx_search` = code search (grep replacement), Context-Mode `ctx_search` = indexed content search (session output). Use lean-ctx for code, Context-Mode for session output.
  - `ctx_execute` — run commands, output auto-indexed
  - `ctx_execute_file` — process large files without loading into context
  - `ctx_search` — search previously indexed content
  - `ctx_batch_execute` — run multiple commands, search results together
  - **Fallback:** If Context-Mode not installed ->
    - `ctx_execute` -> native Bash tool (output not indexed)
    - `ctx_execute_file` -> `Read` tool (loads file into context)
    - `ctx_search` -> `grep`/`find`
    - `ctx_batch_execute` -> parallel Bash calls

- **headroom for large output compression.**
  - **Proxy 模式（推荐）：** 如果 `ANTHROPIC_BASE_URL` 指向 headroom proxy (127.0.0.1:8787)，所有输出自动压缩，无需手动调用。60-95% token 节省。
  - **MCP 模式：** `headroom_compress(large_output)` — 压缩大输出，返回 hash + 摘要（仅当 Proxy 模式未启用时使用）
  - `headroom_retrieve(hash)` — 通过 hash 还原完整内容
  - **Proxy 模式优先于 MCP 模式** — proxy 更优因为零手动操作
  - **Fallback:** If headroom not available -> 直接处理大输出（消耗更多 token）
- **Vertical slice TDD.** One REQ at a time. RED -> GREEN -> REFACTOR. No horizontal slicing.
- **No empty tool calls.** Every Bash/ctx_shell/ctx_execute call MUST have a complete `command` parameter. **Mandatory preflight:** before each Bash call, write `[BASH PREFLIGHT]` in thinking with the full command text. Empty command = InputValidationError = wasted turn. If you can't articulate the command in the preflight, don't call the tool.
- **InputValidationError 路由：** `command` 为空 → 见 [rules.md](rules.md) 无命令不调用 Bash；`taskId` 缺失 → 见 [errors.md](errors.md)#compact-后-task-丢失。不要重试丢失的 taskId。
- **Logging rules:**
  - Entry function: log inputs
  - Exit function: log result
  - Exception: traceback + context (user, operation, data state)
  - Default level WARNING. `--verbose` -> DEBUG

## TDD Loop per REQ

### CONTEXT (before RED)
**MemPalace query trigger — when to call, what to get:**

| REQ involves... | Also query MP for... |
|----------------|---------------------|
| Modifying existing functionality | `mempalace_search query="<feature> implementation" wing="<project>" limit=3` — how was it built before? |
| Similar bug fix pattern | `mempalace_search query="<error keyword> bug" wing="<project>" room="bugs" limit=3` — hit this before? |
| New DB schema change | `mempalace_search query="<table/collection>" wing="<project>" room="knowledge_db" limit=3` — existing patterns? |

**CodeGraph gives you the code. MemPalace gives you the WHY.** Use both.

Before writing tests, understand the code you'll modify:

1. `codegraph_context(task="<REQ description>")` — 获取 REQ 的聚焦上下文（精准，不混入无关代码）
2. `codegraph_search("symbolName")` — 查找特定符号（精准）
3. `codegraph_callers(symbol)` / `codegraph_callees(symbol)` — 调用图边（更准确）
4. `codegraph_impact(symbol)` — 符号变更的影响范围
5. `codegraph_node(symbol)` — 函数签名、完整源码
6. `codegraph_explore(query)` — 多个相关符号源码一次性查看
7. `codegraph_files` — 理解项目文件结构
8. `ctx_search` — 查找之前索引的信息
    - **Fallback:** If Context-Mode unavailable -> `grep` command output
9. `[MP-READ]` `mempalace_search query="<REQ description>" wing="<project>" limit=2` — 恢复跨会话上下文
10. `[MP-READ]` `mempalace_get_drawer drawer_id="<id from search>"` — 获取特定 drawer 的完整内容
11. `[MP-READ]` `mempalace_list_drawers wing="<project>" room="implementation" limit=5` — 浏览最近的实现笔记
    - **Fallback:** If MemPalace unavailable -> skip (codegraph covers session-level context)

### IMPLEMENT — Reuse Gate (MANDATORY before writing any code)

**Before writing ANY code, check for existing reusable code.** This is the primary gate — don't defer to review/simplify.

1. **CodeGraph 搜索** — 查找现有可复用代码：
   - `codegraph_search(query="<functionality needed>")` — 精准查找现有实现（不混入无关代码）
   - `codegraph_explore(query="<functionality>")` — 多个相关符号
2. **[MP-READ] mempalace_search** — 检查跨会话记忆中的先前解决方案：
   - `mempalace_search query="<feature>" wing="<project>" limit=3` — 查找相关实现
3. **Decision:** If existing code can be reused or extended → **reuse it**. Only write new code if nothing fits.

**Rule: Write code ONCE. If it already exists, use it. If it's close, adapt it. Review/Simplify catches what this misses — but this gate should catch 90%.**

### IMPLEMENT (code changes)

Use `[[FILE:edit]]` for file modifications — the adapter resolves to the appropriate edit primitive.

**LSP-powered refactoring (lean-ctx):**
- `ctx_refactor(action="rename", path="<file>", line=<N>, new_name="<name>")` — rename symbol across codebase
- `ctx_refactor(action="references", path="<file>", line=<N>)` — find all references to a symbol
- `ctx_refactor(action="definition", path="<file>", line=<N>)` — go to definition
- `ctx_refactor(action="implementations", path="<file>", line=<N>)` — find implementations of interface/trait
**Why:** LSP refactoring is faster than grep+replace loops and doesn't miss references.

### RED
Write test for REQ-N behavior. Test through public interface, not internals.
```
FAIL: test_xxx for REQ-00X
```
If you don't know what test to write, go back to spec. Don't guess.

### GREEN
**[Brevity First]** Implement minimum code to pass test. No extra logic.
```
PASS: test_xxx for REQ-00X
```

**[MANDATORY] LSP diagnostic gate after GREEN:**
Fallback: `cargo check`, `tsc --noEmit`, `pyright`.
**No dirty type-check = not green.**

### REFACTOR
**[Surgical Edits]** Merge duplicate code with existing code. Minimal change. No architectural restructuring (that's Phase 5). Only touch what's needed to make the test pass.

### REVIEW + SIMPLIFY (MANDATORY after each REQ)
After RED->GREEN->REFACTOR completes, **before moving to next REQ**:
1. **ctx_delta** — `ctx_delta(path)` — incremental diff of changed files, only changed lines (~98% savings vs full read)
2. **git diff** — `[[SHELL:run]] git diff --stat` — verify changes are scoped
3. **Read what you wrote** — read the full context of changes, not just the diff
4. **Simplify** — remove dead imports, flatten unnecessary abstractions, combine redundant loops
5. **Check documentation** — does README/CLAUDE.md need updating?
6. **Verify** — tests still pass after simplifying
7. **Incremental diff check** — `[CALL] ctx_delta(<changed_file>)` — verify only intended lines changed, ~98% savings vs full re-read

**Do not skip this.** Do not move to next REQ without reviewing current changes.

### Worklog Write (MANDATORY after each REQ)

**[CALL] Execute this after every REQ completion. No skip.**

```
[CALL] ctx_shell("echo '<worklog JSON>' >> .doit/worklog.json")
```

**Worklog JSON format:**
```json
{"phase":3,"req":"REQ-00X","desc":"<what was done>","files":["<changed_file>"],"duration":"<approx>","tests":"pass/fail","decision":"<key decision>"}
```

**If filesystem write fails:** Announce `[WARN] worklog failed` and continue. Never block the workflow on worklog failure.
Phase 10 will batch-extract worklog to MemPalace at session end.

**Full Phase 6 review-simplify runs after Phase 5.** Shared source: [shared/review-simplify.md](shared/review-simplify.md)

**Phase sequence:** Phase 3 -> Phase 4 (E2E initial) -> Phase 5 (Review) -> Phase 6 (Review + Simplify) -> Phase 7 (E2E Verification Loop).

### Test Execution

Run tests via context-mode or native Bash:

**Primary (fast path):**
- `ctx_execute` — run test commands, output auto-indexed
- `ctx_batch_execute` — run multiple test commands in parallel

**Fallback:**
- native Bash (output not indexed)

### Spec Alignment Check (Non-Interruptive)

After each REQ completes, present alignment report:
```
REQ-00X DONE. Spec says: "user can do X". Current coverage:
  [x] user can do X with valid input
  [ ] user can do X with edge case Y
```

**铁律: Use [[USER:ask]], never stop and wait.**

```
[[USER:ask]]:
  question: "REQ-00X complete. Proceed to next REQ?"
  header: "REQ-00X"
  options:
    - label: "Yes, continue (Recommended)"
      description: "Proceed to REQ-00(X+1)"
    - label: "Gap found"
      description: "Describe gap between spec and implementation"
```

**If user selects "Yes" or doesn't answer:** proceed to next REQ or Phase 4 (E2E) if last REQ.
**If user describes gap:** fix it, then continue.

### State Tracking

Update `.spec/current.md` status as REQs complete. Cross-session resume uses git branch, commit history, spec REQ statuses, and MemPalace (if available).

After each REQ completes, if MemPalace is active:
```
[MP-WRITE] mempalace_add_drawer wing="<project>" room="implementation" content="REQ-00X: <what was done, key files changed>"
```

### Background Process Management (铁律)

**铁律: 长时间任务必须后台执行 + 轮询。不允许空等。** See [rules.md](rules.md).
**铁律: 所有代码变更必须提交并推送。没有例外。** See [rules.md](rules.md).

完整 tmux + `/loop` 模式见 [background-process.md](background-process.md)。

### Subagent Decision Gate (MANDATORY — Execute Before First REQ)

**[CALL] This gate runs once before Phase 3 execution. No skip. No rationalizing.**

1. Read `.doit/config.yaml` `subagent.enabled` — **default is `false`**
2. If `true`:
   - **[CALL] `codegraph_context(task="<spec summary>")`** — 精准代码图查询
   - **[CALL] `codegraph_impact(symbol="<symbol>")`** — check blast radius for each REQ's target symbols
   - Group REQs by dependency (files modified, symbols touched)
   - **If >= 2 independent REQs exist → LAUNCH parallel agents NOW.** Do not defer. Do not say "I'll do it later."
     - Each independent REQ → one `Agent({isolation: "worktree", run_in_background: true})` call
     - See [subagent.md Conductor Mode](subagent.md) for full prompt template
   - **Announce:** `[SUBAGENT] Mode: parallel (N agents)` — list which REQs → which agent
3. If `false` OR all REQs dependent OR only 1 REQ:
   - Execute sequentially in main agent
   - **Announce:** `[SUBAGENT] Mode: sequential (reason: ...)` — explain why

**铁律: If `subagent.enabled: true` AND 2+ independent REQs exist → parallel launch is mandatory, not optional.** Skipping parallel launch when conditions are met = workflow violation. The announcement is mandatory — lets the user see the decision was made.

### Subagent Parallel TDD (When Decision Gate Says Parallel)

**Config gate:** Read `.doit/config.yaml` `subagent.enabled`. If `true`, launch parallel subagents for independent REQs. If `false` (default), execute sequentially.
**Subagent permissions:** Any subagent has the same tool permissions as the main agent — including codegraph and all MCP servers.

**When:** 2+ REQs have no code dependencies (verified via codegraph code graph). Parallel execution can save 50-70% time.

**Before launching parallel agents:**
1. `codegraph_context(task="<REQ description>")` — verify no code dependencies between REQs
2. `codegraph_impact(symbol="<symbol>")` — check blast radius doesn't overlap

**Launch independent REQs as parallel agents:**

See [subagent.md Conductor Mode](subagent.md) for full orchestration (wave scheduling, supervision, whip mechanism). Quick reference:

```
// REQ-001 and REQ-002 have no dependencies -> parallel
Agent({
  description: "Implement REQ-001",
  prompt: build_conductor_prompt(REQ-001, spec, context),  // See subagent.md template
  subagent_type: "general-purpose",
  isolation: "worktree",  // Independent git branch
  run_in_background: true
})

Agent({
  description: "Implement REQ-002",
  prompt: build_conductor_prompt(REQ-002, spec, context),
  subagent_type: "general-purpose",
  isolation: "worktree",
  run_in_background: true
})

// Conductor 轮询 -> 监督 -> 鞭子机制 -> 结果汇总 -> spec 对齐
// 当后台 agent 完成后，合并 worktree 分支到主分支
```

**Merge worktree results:**
```bash
# After agents complete, merge their worktrees
git merge feat/req-001-branch --no-edit || { echo "merge conflict"; exit 1; }
git merge feat/req-002-branch --no-edit || { echo "merge conflict"; exit 1; }
```

**When NOT to parallelize:**
- REQs modify the same files → merge conflicts
- REQs have dependency relationships → sequential
- Single complex REQ → main flow handles it better

**Cost:** Each agent = separate API call. 2 parallel agents = 2x concurrent tokens, but ~50% faster total time.

## Phase 3 End

**When ALL REQs are done: proceed to Phase 4 (E2E). Code changes are NOT the end of the session.**

Full phase flow: Phase 4 → Phase 5 → Phase 6 → Phase 7 → Phase 8 (commit + push). Every phase runs. See SKILL.md Phase Gate Checklist.
