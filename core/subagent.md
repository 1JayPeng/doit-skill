# Subagent Orchestration (Tool-Agnostic)

**Subagent orchestration is a native capability of most AI coding CLIs.**

**Config gate:** Read `.doit/config.yaml` `subagent.enabled`. Default `false` (disabled). Set to `true` to enable subagent orchestration.

**Subagent tool access:** Subagents get full tool permissions through `general-purpose` agent type. MCP tools (tokensave, context-mode, mempalace) are available to subagents.

## Subagent Tool Access

| Tool | Purpose | Token Savings |
|------|---------|--------------|
| tokensave | Code graph analysis | Replaces grep+Read, 60-80% context reduction |
| context-mode | Session context management | Auto-index commands, semantic search |
| MemPalace | Cross-session semantic memory | Avoid重复 research, context recovery |
| FILE:read/edit/write | File operations | Precise edits, reduced reads |
| SHELL:run | Shell commands | Build, test, git |
| USER:ask | Interactive questions | Non-blocking user decisions |
| AGENT:spawn | Nested subagents | Recursive parallel (use carefully) |

**Subagent via `[[AGENT:spawn]]` gets same tool permissions as main agent.**

## Why Subagents

| Problem | No subagent | With subagent |
|---------|------------|---------------|
| Parallel exploration | Sequential search, context bloat | Multiple agents parallel |
| Large file analysis | Full read into context | Agent in sandbox, returns summary |
| Long tasks | Main flow blocked | Background agent + notification |
| Isolation needs | Main context polluted | Agent independent context |

**Cost:** Each subagent = separate API call. 2 parallel agents = ~2x tokens, but 50-70% faster completion.

## Subagent Primitives (Abstract)

### Basic Launch

```
[[AGENT:spawn description="3-5 word task" prompt="Full task instructions" background=false]]
```

### Background Launch (Non-blocking)

```
[[AGENT:spawn description="Research async patterns" prompt="Search codebase for async/await patterns..." background=true]]
// Main flow continues. Agent notifies on completion.
```

### Worktree Isolation (Independent Git Branch)

```
[[AGENT:spawn description="Implement feature branch" prompt="Implement X in isolated branch..." worktree=true]]
```

### 铁律 — Inherit Main Model

**Never specify `model` parameter. Subagent inherits main conversation's model.**

```
[[AGENT:spawn description="Architecture review" prompt="Review the architecture..." type="plan"]]
[[AGENT:spawn description="Quick file search" prompt="Find all usages of..." type="general"]]
```

### Message (Continue Agent)

```
[[AGENT:message to="<agent_id>" message="New instructions..."]]
```

### Stop Agent

```
[[AGENT:stop task_id="<agent_id>"]]
```

## Available Agent Types

| Type | Use | Tools |
|------|-----|-------|
| **general-purpose** | General research, search, multi-step | All |
| **claude** | Default, any task | All |
| **Explore** | Fast read-only code search | Except Agent, Edit, Write |
| **Plan** | Architecture design, implementation plans | Except Agent, Edit, Write |

**⚠️ Note:** Agent types vary by CLI adapter. See [adapters/](../adapters/) for specifics.

**铁律: Use `general-purpose` or `Plan` types. Avoid `Explore` if it hardcodes specific models.**

### 铁律 — No Same-File Parallel Writes

**Multiple subagents MUST NOT modify the same file in parallel. Violation = data loss.**

```
// ❌ Wrong: two agents modify same file
[[AGENT:spawn description="Fix auth" prompt="...modify src/auth/middleware.rs..." background=true]]
[[AGENT:spawn description="Add rate limit" prompt="...modify src/auth/middleware.rs..." background=true]]

// ✅ Correct: different files → parallel
[[AGENT:spawn description="Fix auth" prompt="...modify src/auth/middleware.rs..." background=true]]
[[AGENT:spawn description="Add rate limit" prompt="...modify src/api/rate-limit.rs..." background=true]]

// ✅ Correct: same file → sequential
[[AGENT:spawn description="Fix auth" prompt="...modify src/auth/middleware.rs..."]]  // blocks
[[AGENT:spawn description="Add rate limit" prompt="...modify src/auth/middleware.rs..."]]  // after
```

**Execution flow (main flow responsibility):**
1. Phase 2: list target_files per REQ via `tokensave_impact` or `tokensave_context`
2. Build file allocation map — REQ-001 → [file_a, file_b], REQ-002 → [file_c]
3. Check file intersection — REQ-001 and REQ-003 share file_a → no parallel
4. No intersection → parallel | Intersection → sequential (more files first)

## Per-Phase Subagent Patterns

### Phase 1: Spec Generation

```
[[AGENT:spawn description="Research existing solutions" prompt="..." background=true]]
[[AGENT:spawn description="Analyze user requirements" prompt="..." background=true]]
[[AGENT:spawn description="Find edge cases" prompt="..." background=true]]
// Main flow: wait for agents, collect results, write spec
```

### Phase 2: Plan with Code Graph

```
[[AGENT:spawn description="Analyze impact module A" prompt="Use tokensave_context to analyze module A impact..." background=true]]
[[AGENT:spawn description="Analyze impact module B" prompt="Use tokensave_context to analyze module B impact..." background=true]]
```

### Phase 3: Execute

```
[[AGENT:spawn description="Write failing tests REQ-001" prompt="..." background=true]]
// Main flow: prepare implementation (GREEN)
// When test agent completes, run tests
```

### Phase 4-7: E2E and Review

```
[[AGENT:spawn description="Run L0 happy path tests" prompt="..." background=true]]
[[AGENT:spawn description="Run L1 boundary tests" prompt="..." background=true]]
```

```
[[AGENT:spawn description="Security review" prompt="Review for security vulnerabilities..." type="general" background=true]]
[[AGENT:spawn description="Architecture review" prompt="Review architecture consistency..." type="plan" background=true]]
[[AGENT:spawn description="Complexity analysis" prompt="Use tokensave_complexity to analyze..." background=true]]
```

## Conductor Orchestration Mode

**Core pattern:** Main agent = Project Manager, subagents = team members. Each subagent has independent worktree, follows doit workflow. Main agent handles Phase 1-2, Phase 4-10. Subagents handle Phase 3 (TDD loop).

**Reference:** Open-source team workflow (Plane, GitHub PR flow). Subagent commit → main agent review → main agent merge.

### Conductor DO / DON'T

**Main agent (Conductor) DO:**
- Build REQ dependency graph → derive waves
- Dispatch subagents (one per REQ)
- Poll subagent progress
- Supervise tool usage and iron rule compliance
- Trigger whip mechanism
- Collect all subagent results
- Verify spec alignment
- Deliver Review + Simplify

**Main agent (Conductor) DON'T:**
- Write implementation code
- Modify business logic files
- Do TDD loops instead of subagents
- Write commits for subagents

### Wave Scheduling — 波次调度器

**Phase 2: annotate dependencies per REQ:**

```
REQ-001: Create user model, dependencies: []
REQ-002: Create auth API, dependencies: [REQ-001]
REQ-003: Create user config API, dependencies: []
REQ-004: Integrate auth middleware, dependencies: [REQ-002]
```

**Wave derivation (topological sort):**

```
Wave 1: [REQ-001, REQ-003]     # No deps, parallel
Wave 2: [REQ-002]               # Depends on REQ-001
Wave 3: [REQ-004]               # Depends on REQ-002
```

**Execution template:**

```
for wave in waves:
  for req in wave:
    [[AGENT:spawn description="<req.description>" prompt="<build_conductor_prompt>" worktree=true background=true]]

  wait_for_all(wave)

  for req in wave:
    result = collect_result(req)
    if not validate_result(result, req):
      handle_failure(req, result)
```

### Deep Supervision — 深度监督机制

**Checklist (after each subagent completes):**

```
[Supervision Checklist]
REQ-XXX: <description>

工具使用:
  [ ] Used tokensave_context/tokensave_search
  [ ] Used context-mode tools (ctx_search, ctx_execute)
  [ ] No forbidden tools (Bash for large output)

TDD 循环:
  [ ] Wrote tests first (RED)
  [ ] Implementation passed tests (GREEN)
  [ ] Tests verified passing

铁律遵守:
  [ ] git commit + push completed
  [ ] MemPalace read/write (if available)
  [ ] Background execution (commands >10s)
  [ ] No files modified outside REQ scope

产出质量:
  [ ] Modified files match Phase 2 plan
  [ ] Test coverage > 0
  [ ] No compilation errors
```

**Subagent result must be structured:**

```
[Agent Result]
REQ: REQ-001
Status: PASS | FAIL | PARTIAL
Files Modified: [file1, file2]
Tests: PASS (3/3) | FAIL (1/3)
Commit: abc1234 (pushed)
Tools Used: [tokensave_context, Edit, Bash]
Iron Rules Violated: [] | [detail]
Notes: <optional>
```

### Whip Mechanism — 鞭子机制

**三级升级:**

```
Level 1 — Progress check:
  Trigger: 50% over expected time
  Action: [[AGENT:message to=agent_id message="进度检查：你目前的进展如何？列出已完成和待完成项。"]]

Level 2 — Correction:
  Trigger: Level 1 no response or off-track
  Action: [[AGENT:message to=agent_id message="修正：你偏离了 REQ-XXX 的目标。正确做法是 [具体指令]。立即回到正轨。"]]

Level 3 — Kill and restart:
  Trigger: Level 2 no response or confirmed hang
  Action:
    1. [[AGENT:stop task_id=agent_id]]
    2. Analyze failure cause
    3. Fix prompt
    4. [[AGENT:spawn ...]] with corrected prompt
```

### Rule Injection — 规则注入机制

**Problem:** Subagents have independent context windows. They don't inherit main conversation's SKILL.md rules.

**Solution:** Conductor prompt template MUST inject full iron rules, not summarized abstracts. Subagent prompt = subagent's SKILL.md.

**Rule injection principles:**
1. Full injection, not summary
2. Violation consequences explicit (whip mechanism trigger)
3. Self-audit mandatory before return
4. Main agent also constrained by SKILL.md

### Conductor Prompt Template

```
build_conductor_prompt(req, spec, context):
  return f"""
  ## 任务：{req.description}
  ## REQ ID: {req.id}
  ## 验收标准：
  {req.acceptance_criteria}

  ## 目标文件（只修改这些文件）：
  {req.target_files}
  ## 依赖：{req.dependencies}（已完成）

  ## 上下文：
  {context}  # tokensave_context result

  ## ===== 铁律（必须遵守） =====

  ### 铁律 1：工具使用规范
  - MUST use tokensave_context to understand code
  - MUST use context-mode tools (ctx_search, ctx_execute)
  - MUST NOT use Explore agent (use general-purpose)
  - MUST NOT use Bash for output >20 lines

  ### 铁律 2：TDD 循环不可跳过
  - Step 1: Write tests (RED) — tests must fail
  - Step 2: Write minimal impl (GREEN) — tests must pass
  - Step 3: Run tests — confirm passing

  ### 铁律 3：后台执行
  - >10s commands: MUST use background=true or &
  - >5min commands: MUST use tmux + Monitor

  ### 铁律 4：Commit + Push 必须完成
  - git add -> git commit -> git push
  - commit message format: type: description

  ### 铁律 5：MemPalace 读写对称
  - If MemPalace available: MUST read/write
  - If MemPalace unavailable: skip silently

  ### 铁律 6：同文件不并行
  - You own your target files
  - Don't modify files outside target list

  ### 铁律 7：文件范围不超出 REQ
  - Only modify files in target list
  - Don't add features not in spec

  ### 铁律 8：危险操作保护
  - No DROP TABLE, TRUNCATE, DELETE without WHERE
  - No rm -rf / rm -r / rm -f
  - No git push --force / git reset --hard
  - If deletion needed: confirm via [[USER:ask]]

  ## 返回格式：
  [Agent Result]
  REQ: {req.id}
  Status: PASS | FAIL | PARTIAL
  Files Modified: [...]
  Tests: PASS (X/Y) | FAIL (X/Y)
  Commit: <hash> (pushed to <branch>)
  Tools Used: [...]
  Iron Rules Violated: [] | [rule_number: detail]
  """
```

### When NOT to Use Subagents

| Scenario | Reason | Alternative |
|----------|--------|-------------|
| Modify same file | Conflict risk | Sequential main flow |
| Need user input | Agent can't interact | Main flow + `[[USER:ask]]` |
| Simple one-line command | Agent overhead > direct exec | Direct `[[SHELL:run]]` |
| Need real-time feedback | Agent results delayed | Main flow direct exec |
| Context < 500 lines read | Agent overhead not worth it | Direct `[[FILE:read]]` |

### Error Handling

```
1. Agent spawn fails → fallback to main flow direct exec
2. Agent timeout → check worktree state, recover partial results
3. Agent produces conflicts → main flow merge, resolve
4. Worktree cleanup → auto-clean after agent completes (if no changes)
```
