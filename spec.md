# Phase 1: Spec Generation

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
  subagent_type: "Explore",
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

### Step 2: Grill

Use `grill-me` skill to pressure-test the idea. Find holes, contradictions, scope creep. Resolve each before proceeding.

**铁律: Grill questions via AskUserQuestion, never stop and wait.**

When the grill reveals ambiguity, present it as AskUserQuestion:
```
AskUserQuestion:
  question: "Grill found ambiguity: Should X handle Y case?"
  header: "Grill"
  options:
    - label: "Yes, include Y (Recommended)"
      description: "Handle Y as part of this feature"
    - label: "No, out of scope"
      description: "Defer Y to future work"
    - label: "Depends, clarify"
      description: "Need more context"
```

If user doesn't answer -> use the recommended default and continue. Grill should not block the workflow.

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

### Step 6: File to MemPalace (if available)

Phase 0 memory sweep already loaded project context. Here, search for related prior specs, check for duplicates, and file:

```
# Search for related prior specs (context sweep already ran in Phase 0)
mempalace_search query="<feature keywords>" wing="<project>" room="specs" limit=3

# Check for near-duplicates before filing
mempalace_check_duplicate content="<spec content>" threshold=0.87

# If not duplicate: file the new spec
mempalace_add_drawer wing="<project>" room="specs" content="<full spec content>" source_file=".spec/current.md"
```

If scope changes during grill and a related spec exists, update it instead of creating a duplicate:
```
mempalace_update_drawer drawer_id="<id from search>" content="<updated spec content>"
```

If MemPalace is unavailable, skip silently. Filesystem (`.spec/current.md`) is the primary source of truth.
