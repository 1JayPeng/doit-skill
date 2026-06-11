# CodeGraph Integration

**Pre-built code graph index** — answers structural questions without grep/read loops.

---

## Installation

```bash
# Global install
npm i -g @colbymchenry/codegraph

# Install MCP server
codegraph install --yes

# Initialize project index (first-time)
codegraph init -i
```

**Verify:**
```bash
codegraph --version
claude mcp list | grep codegraph
```

---

## MCP Tools (Available in Workflow)

CodeGraph delivers its usage guidance automatically via MCP initialize response — no instructions file needed.

| Tool | Use For |
|------|---------|
| `codegraph_explore` | **Primary** — "how does X work", flows, surveying an area (returns symbols grouped by file) |
| `codegraph_search` | Locate a symbol by name |
| `codegraph_callers` | Who calls this symbol (upward call flow) |
| `codegraph_callees` | What does this symbol call (downward call flow) |
| `codegraph_impact` | Impact radius before editing |
| `codegraph_node` | Full source of one specific symbol (all overloads) |

---

## Usage in Doit Workflow

### Phase 2 — Plan (Code Graph Scan)

**Primary alternative to TokenSave** when TokenSave is unavailable or for cross-language projects:

1. `codegraph_explore` — understand how a feature works, survey code area (PRIMARY)
2. `codegraph_search` — locate specific symbols by name
3. `codegraph_callers` / `codegraph_callees` — walk call flow
4. `codegraph_impact` — assess edit blast radius
5. `codegraph_node` — get full source of a specific symbol

### Phase 3 — Execute

- `codegraph_impact` before high-impact edits
- `codegraph_explore` for understanding existing implementation before modification

### Key Principles

- **Trust the results** — don't re-verify with grep. The index is pre-built.
- **Treat returned source as already read** — no need to re-read files.
- **Check staleness banner** after edits — re-index if needed.
- **If `.codegraph/` doesn't exist**, offer to run `codegraph init -i`.

---

## Integration Points

| File | Change |
|------|--------|
| `package.json` | Added to `tools` section |
| `scripts/setup.sh` | Step 3.8: install + init |
| `env-check.md` | Tool availability check |
| `tool-integration-guide.md` | Tool overview + Phase usage |
| `.gitignore` | `.codegraph/` |

---

## What CodeGraph is NOT

- **Not a replacement for TokenSave** — complementary. TokenSave has deeper Rust-specific analysis (traits, derives, impl blocks). CodeGraph excels at cross-language projects.
- **Not an editor** — read-only code graph queries.
- **Not a memory system** — code structure only, no semantic memory.
