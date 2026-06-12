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
  - `ctx_search(pattern, path)` — 搜索代码（比 Grep 输出小 60%）
  - `ctx_tree(path, depth)` — 列目录（比 ls 输出小 80%）
  - `ctx_shell(command)` — 执行命令（95+ 压缩模式）
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

- **headroom for large output compression.** 当任何工具返回 >500 行输出时，先压缩再处理。
  - `headroom_compress(large_output)` — 压缩大输出，返回 hash + 摘要
  - `headroom_retrieve(hash)` — 通过 hash 还原完整内容
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
Before writing tests, understand the code you'll modify:

**CodeGraph + TokenSave 互补并行**：
1. `codegraph_context(task="<REQ description>")` — 获取 REQ 的聚焦上下文（精准，不混入无关代码）
2. `tokensave_context(task="<REQ description>")` — 即时检测文件改动，交叉验证 CodeGraph 结果
3. `codegraph_search("symbolName")` — 查找特定符号（精准）
4. `tokensave_search("symbolName")` — 改动后立即生效的符号查找
5. `codegraph_callers(symbol)` / `codegraph_callees(symbol)` — 调用图边（更准确）
6. `codegraph_impact(symbol)` — 符号变更的影响范围
7. `codegraph_node(symbol)` — 函数签名、完整源码
8. `codegraph_files` — 理解项目文件结构
9. `tokensave_diagnostics(scope="workspace")` — 运行类型检查器（cargo check / tsc / pyright）
10. `tokensave_test_map(node_id="<id>")` — 查找符号的测试覆盖率
11. `tokensave_affected_tests(files=[<changed_files>])` — 查找受影响的测试文件
12. `tokensave_similar(symbol="<name>")` — 查找相似名称的符号（避免命名不一致）
13. `tokensave_body(symbol="<name>")` — 返回符号的完整源码体（比 node 查找更快）
14. `tokensave_signature(qualified_name="<name>")` — 获取函数签名（不含源码体）
15. `tokensave_signature_search(params="&mut self", returns="Result")` — 按签名形状查找函数
16. `ctx_search` — 查找之前索引的信息
    - **Fallback:** If Context-Mode unavailable -> `grep` command output
17. `[MP-READ]` `mempalace_search query="<REQ description>" wing="<project>" limit=2` — 恢复跨会话上下文
18. `[MP-READ]` `mempalace_get_drawer drawer_id="<id from search>"` — 获取特定 drawer 的完整内容
19. `[MP-READ]` `mempalace_list_drawers wing="<project>" room="implementation" limit=5` — 浏览最近的实现笔记
    - **Fallback:** If MemPalace unavailable -> skip (codegraph + tokensave cover session-level context)

**使用策略：**
- **规划阶段**：`codegraph_context` + `tokensave_context` 并行调用
- **符号查找**：`codegraph_search`（精准），`tokensave_search`（改动后即时检测）
- **调用图**：`codegraph_callers/callees`（更准确）
- **质量分析**：`tokensave_diagnostics/test_map/affected_tests`
- **代码编辑**：`tokensave_str_replace` / `tokensave_multi_str_replace` / `tokensave_insert_at`
### IMPLEMENT — Reuse Gate (MANDATORY before writing any code)

**Before writing ANY code, check for existing reusable code.** This is the primary gate — don't defer to review/simplify.

1. **CodeGraph + TokenSave 并行搜索** — 查找现有可复用代码：
   - `codegraph_search(query="<functionality needed>")` — 精准查找现有实现（不混入无关代码）
   - `tokensave_search(query="<functionality needed>")` — 即时检测改动后的代码
   - `tokensave_signature_search(params="<key param>", returns="<return type>")` — 按签名形状查找函数
2. **tokensave_similar** — 检查是否存在相似函数：
   - `tokensave_similar(symbol="<new_function_name>")` — 查找命名冲突或近似重复
3. **[MP-READ] mempalace_search** — 检查跨会话记忆中的先前解决方案：
   - `mempalace_search query="<feature>" wing="<project>" limit=3` — 查找相关实现
4. **Decision:** If existing code can be reused or extended → **reuse it**. Only write new code if nothing fits.

**Rule: Write code ONCE. If it already exists, use it. If it's close, adapt it. Review/Simplify catches what this misses — but this gate should catch 90%.**

### IMPLEMENT (edit primitives for code changes)

Use tokensave edit primitives instead of Read+Edit when modifying source files — they trigger in-place re-index so the graph never goes stale:
- `tokensave_str_replace` — replace a unique string; fails if 0 or >1 matches (safe single-edit)
- `tokensave_multi_str_replace` — apply N replacements atomically (all-or-nothing transaction)
- `tokensave_insert_at` — insert content before/after an anchor string or line number
- **Fallback:** If TokenSave unavailable -> native Read + Edit tools

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

### REFACTOR
**[Surgical Edits]** Merge duplicate code with existing code. Minimal change. No architectural restructuring (that's Phase 5). Only touch what's needed to make the test pass.

### REVIEW + SIMPLIFY (MANDATORY after each REQ)
After RED->GREEN->REFACTOR completes, **before moving to next REQ**:
1. **tokensave scan** — `tokensave_simplify_scan(files=[<changed_files>])` — auto-detect duplications, dead code, complexity
2. **tokensave_similar** — `tokensave_similar(symbol="<new_function_name>")` — check if a similarly named symbol already exists (naming inconsistency)
3. **Read what you wrote** — read the full context of changes, not just the diff
4. **Simplify** — remove dead imports, flatten unnecessary abstractions, combine redundant loops
5. **Check documentation** — does README/CLAUDE.md need updating?
6. **Verify** — tests still pass after simplifying

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

Run only affected tests when possible — skip full suite for small changes:

**Primary (fast path):**
- `tokensave_affected_tests(files=[<changed_files>])` — find test files affected by changed source files
- `tokensave_run_affected_tests(changed_paths=[<changed_files>])` — run only affected tests (cargo test)
- For non-Rust projects: use `ctx_execute` with affected test files

**Fallback (full suite):**
- `ctx_execute` — run all test commands, search results with `ctx_search`
- `ctx_batch_execute` — run multiple test commands, search all output together
- **Context-Mode unavailable:** run tests via native Bash. Output printed to context (more tokens used).

### Spec Alignment Check (Non-Interruptive)

After each REQ completes, present alignment report:
```
REQ-00X DONE. Spec says: "user can do X". Current coverage:
  [x] user can do X with valid input
  [ ] user can do X with edge case Y
```

**铁律: Use AskUserQuestion, never stop and wait.**

```
AskUserQuestion:
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
   - **[CALL] `tokensave_context(task="<spec summary>")`** — 即时检测改动，交叉验证
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
**Subagent permissions:** Any subagent has the same tool permissions as the main agent — including tokensave, codegraph, and all MCP servers.

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
