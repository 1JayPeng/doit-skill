# Phase 1: Spec Generation

**[Think Before Coding]** Challenge assumptions before writing any code. Grill the user's idea, present alternatives, expose hidden complexity.

## Input

Raw user request (natural language, any length).

## Process

### Step 1: Internet Brainstorm

**Before grilling, search the web for relevant context.**

- **Primary:** Use Tavily MCP remote server:
  ```bash
  # The Tavily MCP server connects to:
  # https://mcp.tavily.com/mcp/?tavilyApiKey=<user-api-key>
  ```
- **Fallback:** If Tavily MCP not configured -> use built-in `WebSearch` tool. Same search, slightly slower.

Search for:
- Existing solutions, libraries, or patterns for the requested feature
- Common pitfalls, edge cases people hit in the wild
- Competitive/alternative approaches the user may not know about
- Framework best practices relevant to this feature

**Use search results to inform grill questions.** Real-world data makes grill sharper.

#### Subagent Parallel Research (Optional, when 2+ independent research topics)

When the feature requires research across multiple independent domains, launch parallel agents instead of sequential searches. See [subagent.md](subagent.md) for full patterns.

```
// Detect 2+ independent research topics -> parallel agents
Agent({
  description: "Research competitive solutions",
  prompt: "使用 WebSearch 搜索 '<feature> competitive solutions 2026'，汇总前 5 个方案，包括优缺点...",
  subagent_type: "general-purpose",
  run_in_background: true
})

Agent({
  description: "Research existing code patterns",
  prompt: "使用 tokensave_context 分析当前项目中与 '<feature>' 相关的现有代码...",
  subagent_type: "general-purpose",
  run_in_background: true
})

Agent({
  description: "Research security requirements",
  prompt: "使用 WebSearch 搜索 'OWASP <feature> security requirements 2026'，提取关键安全要求...",
  subagent_type: "general-purpose",
  run_in_background: true
})

// 主流程继续：准备 grill 问题框架
// 当后台 agent 完成后，汇总结果，填充 grill 问题
```

**When to use:** Feature spans 2+ domains (e.g., auth + database + UI). Each domain gets one agent.
**When to skip:** Single-domain feature, or research topics have dependencies between them.
**Cost:** Each agent = one API call. haiku models save ~90% vs opus. 3 parallel haiku agents ~ 1 opus agent cost.

### Step 2: Grill (MANDATORY minimum 5 questions for Type F, 3 for Type B)

Use `grill-me` skill to pressure-test the idea. Find holes, contradictions, scope creep. Resolve each before proceeding.

**铁律: Grill questions via AskUserQuestion, never stop and wait.**
**铁律: Minimum 5 grill questions per feature (Type F), 3 per bug (Type B). < minimum = incomplete Phase 1 = cannot proceed to Phase 2.**
**铁律: Every grill question MUST provide concrete, actionable options — not open-ended questions.**

**Option Quality (MANDATORY per question):**
Each `AskUserQuestion` option MUST contain:
1. **Named approach** — "JWT Stateless" not "option A"
2. **Consequence** — what happens: `-> 无服务端状态，移动端天然兼容`
3. **Trade-off** — what you lose: `Trade-off: 撤销token需黑名单`
4. **Project fit** — why it fits THIS project: `适合: 本项目移动端优先场景`
5. **Recommendation** — exactly one `(Recommended)` with project-specific reason

**Bad option:** `label: "Redis", description: "Fast caching with Redis"`
**Good option:** `label: "Redis cache (Recommended)", description: "In-memory -> sub-ms read, needs Redis infra. Trade-off: cache invalidation. 适合: 高读低写配置查找。"`

**Step 2a: Research + Uncertainty Scan (internal, before generating questions):**
1. **Research first** — Tavily MCP + MP search + TokenSave for project context
2. **Uncertainty scan** — List 3-5 things uncertain, rate 1-5. Generate questions for items >= 3.
3. **Build options from research** — Each option backed by data, not guesswork

**GRILL CHECKLIST — all must complete before writing REQs:**
- [ ] Challenge assumptions — at least 1 question
- [ ] Internet search for existing solutions — Tavily MCP or WebSearch
- [ ] MP search for prior specs/knowledge — `mempalace_search wing="<project>"`
- [ ] Alternative approaches — at least 1 question
- [ ] Scope clarification — at least 1 question
- [ ] **Every option has consequence + trade-off + project fit**
- [ ] **Exactly one (Recommended) per question with justification**

**Step 2b: Grill Summary (after grill complete, before REQs):**
Write `.doit/grill-summary.json`:
```json
{
  "questions_asked": 5,
  "checklist": {"challenge_assumptions": true, "internet_search": true, "mp_search": true, "alternative_approaches": true, "scope_clarification": true, "option_quality": true},
  "questions": ["Q1 text", "Q2 text", ...],
  "answers": {"Q1": "user answer or default used"}
}
```

When the grill reveals ambiguity, present it as AskUserQuestion:
```
AskUserQuestion:
  question: "Grill found ambiguity: Should X handle Y case — 选择影响范围定义和后续扩展？"
  header: "Scope"
  options:
    - label: "Yes, include Y (Recommended)"
      description: "Handle Y as part of this feature -> 一次性解决，~2天额外。适合: Y和X共享80%代码路径。"
    - label: "No, out of scope"
      description: "Defer Y to future work -> 当前范围缩小~30%。Trade-off: 下次需要兼容层。适合: Y和X代码路径独立。"
```

After asking all grill questions: if user doesn't answer within the same response cycle -> use the recommended default and continue. Grill questions MUST be asked before defaults are applied. Skipping grill questions entirely is NOT equivalent to user not answering.

### Step 3: Split to Acceptance Criteria

Break grill output into REQ-N items. Each REQ:
- Unique ID: REQ-001, REQ-002...
- One behavior, one test (independent)
- Status: TODO (default)
- Has blocking relationship to other REQs? Mark BLOCKED

### Step 4: Write Spec File

Save to `.spec/current.md`:

```md
# Feature: [name]

## Branch
`feature/[short-name]`

## Description
[What + why, not how]

## Acceptance Criteria
| ID | Description | Status | Blocked By |
|----|-------------|--------|------------|
| REQ-001 | ... | TODO | - |
| REQ-002 | ... | TODO | REQ-001 |

## E2E Scenario
[Full user journey from start to finish]
```

### Step 5: Create Branch

```bash
git checkout -b feature/[short-name]
```

Copy spec to branch (it stays in git).

### Step 6: MemPalace

Phase 0 memory sweep already loaded project context. Use it here.

**[MP-READ] Search for related prior specs (before grilling, use Phase 0 sweep results):**
```
mempalace_search query="<feature keywords>" wing="<project>" room="specs" limit=3
```
Use findings to inform grill questions — avoid repeating already-decided specs.

**[MP-WRITE] File spec to MemPalace (after writing .spec/current.md):**
```
mempalace_check_duplicate content="<spec content>" threshold=0.87
mempalace_add_drawer wing="<project>" room="specs" content="<full spec content>" source_file=".spec/current.md"
```
If scope changes during grill and a related spec exists, update instead:
```
mempalace_update_drawer drawer_id="<id from check_duplicate>" content="<updated spec content>"
```
MP unavailable -> skip silently. Filesystem (`.spec/current.md`) is primary.
