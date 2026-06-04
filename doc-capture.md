# Doc Capture

Captures user-provided reference documents into `.doit/docs/`, indexes with tokensave, and injects CLAUDE.md references for persistence.

## When to Trigger

Run immediately after Phase 0 classification when the user's prompt contains reference documentation:

**Trigger signals:**
- Pasted API endpoint definitions, OpenAPI/Swagger specs
- "Here's our API docs", "our convention is", "the business rules are"
- Structured content (tables, endpoint lists, config schemas) reading as reference material, not a task
- Code blocks with configuration, schema, or interface definitions the user wants Claude to always know about

**Do not capture:**
- Code they want implemented (feature request)
- Error messages (bug report)
- Short descriptions without lasting reference value

## Steps

### 0. Check Config

Read `.doit/config.yaml` — check `doc-capture.enabled`. If false, skip silently.

Check `doc-capture.mode`:
- `off` — skip
- `ask` — confirm with user before saving each doc
- `auto` — save silently (default)

### 1. Extract Document Content

Extract the document from the user's message. Preserve original formatting (tables, code blocks, headings). Wrap in a markdown heading describing the topic.

### 2. Create .doit/docs/ and Save

```bash
mkdir -p .doit/docs  # or use doc-capture.path from config
```

Write to `.doit/docs/<descriptive-name>.md`:
```markdown
---
source: doit doc-capture
date: <today>
description: Brief one-line description of doc content
---

<original document content here>
```

**Naming convention:** kebab-case, descriptive (`api-endpoints.md`, `auth-convention.md`, `business-rules.md`)

**Existing file:** if the target file exists, check content hash:
- Same content → skip
- Different content → ask user: append / overwrite / new name

### 3. Verify Tokensave Index

```
tokensave_search(query="<doc keyword>")
```

The `.doit/` directory is inside the project root so tokensave indexes it automatically. No extra config needed.

### 4. Inject CLAUDE.md Reference

Add/update `## Reference Docs` section in project's `CLAUDE.md`:

```markdown
## Reference Docs

Reference documents stored in `.doit/docs/`. Consult when working on related tasks:
- [.doit/docs/api-endpoints.md](.doit/docs/api-endpoints.md) — API endpoint definitions. Consult when adding or modifying API endpoints.
```

**Format per doc entry:** `[filename](path) — brief description. When to consult.`

If section exists, append new entries (deduplicate by filename).

If CLAUDE.md doesn't exist, create it with just the reference docs section.

### 5. File to MemPalace (if available)

If MemPalace is active, also file the doc for cross-project semantic search:

```
mempalace_check_duplicate content="<doc content>" threshold=0.87
```

If not a duplicate:

```
mempalace_add_drawer wing="<project>" room="reference-docs" content="<doc content>" source_file="<original source>"
```

If MemPalace is unavailable or content is a duplicate, skip silently. Filesystem (`.doit/docs/`) remains the primary source of truth.

### 6. Announce to User

```
[DOC-CAPTURE] Saved to .doit/docs/api-endpoints.md
[DOC-CAPTURE] Indexed by tokensave
[DOC-CAPTURE] Updated CLAUDE.md Reference Docs section
[DOC-CAPTURE] Filed to mempalace (if available)
```

### 7. Skip if User Says So

If user says "don't save", "keep in context", skip silently.
