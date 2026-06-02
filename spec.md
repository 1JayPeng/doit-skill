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

Phase 0 memory sweep already loaded project context. Here, just search for directly related prior specs and file the new one:

```
# Search for related prior specs (context sweep already ran in Phase 0)
mempalace_search query="<feature keywords>" wing="<project>" room="specs" limit=3

# File the new spec
mempalace_add_drawer wing="<project>" room="specs" content="<full spec content>" source_file=".spec/current.md"
```

If scope changes during grill and a related spec exists, update it instead of creating a duplicate:
```
mempalace_update_drawer drawer_id="<id from search>" content="<updated spec content>"
```

If MemPalace is unavailable, skip silently. Filesystem (`.spec/current.md`) is the primary source of truth.
