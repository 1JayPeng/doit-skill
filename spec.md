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

If MemPalace is active, file the spec for cross-session recovery:

```
mempalace_add_drawer wing="<project>" room="specs" content="<full spec content>" source_file=".spec/current.md"
```

Also search for related prior specs to avoid repeating decisions:

```
mempalace_search query="<feature keywords>" wing="<project>" limit=3
```

If MemPalace is unavailable, skip silently. Filesystem (`.spec/current.md`) is the primary source of truth.
