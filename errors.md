# Error Handling

## Failures by Phase

### Phase -1 (Environment Detection) Fail

Cannot determine project environment. Found conflicting signals or nothing at all.

**Action:** Ask the user. Do not guess. Present what was found and let user choose.

### Phase 1 (Spec) Fail
Grill reveals idea is unworkable (tech infeasible, self-contradictory).

**Action:** Terminate. Tell user why. Zero code generated -> zero loss.

### Phase 1 (Spec) — Grill Skipped
Phase 1 completed or Phase 2 started without minimum grill questions via AskUserQuestion.

**Action:** Stop. Return to Phase 1 Step 2. Complete the full grill checklist (uncertainty scan, 5+ questions, internet search, MP search, grill summary). Do not discard REQs already written — use grill findings to supplement them, then merge into existing REQs.

### D0 (Diagnose) Fail
Cannot reproduce the bug.

**Action:** Tell user. Don't guess. Do not write code based on a hunch. Ask user for more details about environment, input, and expected behavior.

### D1 (Regression Test) Fail
Can't write a test that fails. Either the bug is too deep (infrastructure/env) or you can't reproduce it.

**Action:** Tell user. Don't skip the regression test.

### Phase 3 (Execute) Fail
TDD stuck on REQ-N. Previous REQs conflict with current.

**Action:** Stop. Re-grill (back to Phase 1 partial). Discard unverified code from failed REQ. Keep passing code.

### Phase 5 (Review) Fail
Code works but has architectural/security issues.

**Action:** Retain code on branch (`feature/xxx`). Don't merge. Present options:
1. Fix the issue -> continue on same branch
2. Accept as tech debt -> mark in spec, merge with caveat
3. Re-do from scratch -> discard and re-plan

### Phase 6 (Review+Simplify) Fail
Code has duplication, over-engineering, or documentation doesn't match new behavior.

**Action:** Fix immediately — no need to go back to earlier phases. This is cleanup, not redesign. Common fixes:
1. Merge duplicated functions
2. Remove dead code / unused imports
3. Update README/CLAUDE.md to match new behavior
4. Flatten unnecessary abstractions

**Phase 6 is a self-correction step.** If you find issues here, fix them and re-run Phase 6 until it passes. Do not report to user unless you find a fundamental design flaw that requires going back to Phase 1.

### Phase 7 (E2E Verification) Fail

E2E tests fail after Review + Simplify. Simplify broke user-facing behavior.

**Action:** Don't panic — this is exactly why the loop exists. Debug which simplify change caused the regression, revert or fix it, re-run e2e. Loop up to 3 times. After 3 failures, escalate to user.

### Phase 7 (Spec Alignment) Fail

E2E tests pass but output doesn't match spec REQs. This means simplify changed behavior to something that works but isn't what the user asked for.

**Action:** Fix the code output to match spec. Never change the spec to match a broken output. Re-run e2e + spec alignment check. If fix requires significant rework, escalate to user.

### Phase 8 (Commit) Fail

Staged changes conflict or cannot be committed.

**Action:** Resolve the specific conflict (merge, rebase, or re-stage). Do not use `--no-verify` or `--force` to bypass hooks. If the commit itself reveals issues (e.g., pre-commit hook failures), fix them and retry. Do not roll back to earlier phases — this is a git operation, not a code quality issue.

## Session Recovery

Session restart with existing branch:
1. **MemPalace recovery** (if available): `mempalace_diary_read agent_name="doit" last_n=3` + `mempalace_search query="<project>" wing="<project>" limit=5`
2. Read `.spec/current.md` from branch
3. Check REQ status table
4. Resume at first non-DONE REQ

No spec, no branch -> start fresh from Phase 0.

## MemPalace Unavailable

If MemPalace tool calls error during any phase, skip silently. Filesystem (`.doit/docs/`, `.spec/archive/`) and tokensave code graph remain as the primary persistence layers. The workflow never blocks on a missing memory layer.

## Compact 后 Task 丢失

Compact 压缩上下文后，`TaskUpdate` 可能因 `taskId` 丢失而报错：
`InputValidationError: TaskUpdate failed due to the required parameter taskId is missing`

**根因：** `headroom_compress` 压缩对话上下文，task 状态（taskId）从摘要中丢失。系统恢复阶段尝试调用 `TaskUpdate` 但参数不完整。

**处理：**
1. 调用 `TaskList` 检查当前状态
2. 如有过期 task，标记为 `deleted` 清理
3. **不要重试 `TaskUpdate`** — taskId 已丢失，重试无意义
4. 如需新建 task，调用 `TaskCreate` 重新创建

**预防：** Phase 10 结束必须运行 `headroom_compress`。Compact 后自动清理 task 列表，不要保留对旧 taskId 的引用。

## InputValidationError 路由表

**当出现 InputValidationError 时，[LOAD] [tool-params.md](tool-params.md) 查看工具签名。**

| Error | Root Cause | Fix |
|-------|-----------|-----|
| `command is missing` (Bash) | Empty command param | [BASH PREFLIGHT] in thinking first |
| `file_path is missing` (Read/Edit) | Forgot absolute path | Use absolute path, Read before Edit |
| `old_string is missing` (Edit) | Forgot search string | Provide exact text from Read output |
| `description is missing` (Agent) | Missing description+prompt | Both `description` AND `prompt` required |
| `subject is missing` (TaskCreate) | Missing required fields | Both `subject` AND `description` required |
| `taskId is missing` (TaskUpdate) | Compact lost taskId | See "Compact 后 Task 丢失" above |
| `questions is missing` (AskUserQuestion) | Missing questions array | Array of {question, header, options, multiSelect} |
| `path is missing` (ctx_read) | Missing file path | Use absolute path for ctx_read |

**关键原则：** 永远不要用相同参数重试失败的工具调用。先检查 [tool-params.md](tool-params.md) 确认签名。

## InputValidationError 路由表

**当出现 InputValidationError 时，[LOAD] [tool-params.md](tool-params.md) 查看工具签名。**

| Error | Root Cause | Fix |
|-------|-----------|-----|
| `command is missing` (Bash) | Empty command param | [BASH PREFLIGHT] in thinking first |
| `file_path is missing` (Read/Edit) | Forgot absolute path | Use absolute path, Read before Edit |
| `old_string is missing` (Edit) | Forgot search string | Provide exact text from Read output |
| `description is missing` (Agent) | Missing description+prompt | Both `description` AND `prompt` required |
| `subject is missing` (TaskCreate) | Missing required fields | Both `subject` AND `description` required |
| `taskId is missing` (TaskUpdate) | Compact lost taskId | See "Compact 后 Task 丢失" above |
| `questions is missing` (AskUserQuestion) | Missing questions array | Array of {question, header, options, multiSelect} |
| `path is missing` (ctx_read) | Missing file path | Use absolute path for ctx_read |

**关键原则：** 永远不要用相同参数重试失败的工具调用。先检查 [tool-params.md](tool-params.md) 确认正确签名。
