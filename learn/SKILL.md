---
name: knowledge-distillation
description: Extract and reuse knowledge from doit sessions. Automatically captures successful patterns, decisions, errors, and code patterns from completed sessions. Injects relevant past knowledge during Phase 1/2 to prevent repeating mistakes. Use when doit sessions complete (Phase 9.5.5) for extraction, or when Phase 1/2 starts for injection. Also use for /doit-learn to manually trigger knowledge extraction from historical data.
---

# Knowledge Distillation

Capture successful patterns from doit sessions and reuse them to accelerate future development.

## Overview

This module integrates with doit-skill's workflow to automatically:

1. **Extract** knowledge at Phase 9.5.5 (after completion summary)
2. **Store** in primary layers (mempalace + filesystem)
3. **Inject** relevant past knowledge at Phase 1/2 (before grill/planning)

## Workflow Integration

### Phase 9.5.5: Knowledge Extraction

**Trigger:** After Phase 9.5 Completion Summary, before Phase 10

**Process:**
1. Gather session data (git diff, worklog, spec, grill decisions)
2. Generate structured knowledge record ([schema.json](schema.json))
3. Present to user for confirmation/edit
4. Save to multi-layer storage
5. Report extraction status

**Details:** [extract.md](extract.md)

### Phase 1/2: Knowledge Injection

**Trigger:** Before Phase 1 grill questions and Phase 2 impact analysis

**Process:**
1. Generate search query from user request
2. Search multi-layer knowledge base
3. Rank by relevance + time decay
4. Inject top-3 relevant past sessions into context
5. Use injected knowledge to improve grill questions and planning

**Details:** [inject.md](inject.md)

### Historical Data Migration

**Trigger:** First run after installation, or manual `/doit-learn` command

**Process:**
1. Extract knowledge from git commit history
2. Extract from existing MemPalace drawers
3. Extract from worklog entries
4. Convert to structured format
5. Deduplicate and save

**Details:** [migrate.md](migrate.md)

## Knowledge Record Schema

Structured JSON format for knowledge records:

```json
{
  "id": "uuid-v4",
  "timestamp": "ISO-8601",
  "project": "project-name",
  "type": "F|B|S",
  "status": "success|failed|partial",
  "summary": "One-line description",
  "reqs": ["REQ-001: ..."],
  "decisions": [{"question": "...", "choice": "...", "rationale": "..."}],
  "errors": [{"error": "...", "root_cause": "...", "resolution": "..."}],
  "code_patterns": [{"pattern": "...", "files": ["..."], "context": "..."}],
  "files_changed": ["..."],
  "lines_added": 100,
  "lines_removed": 50,
  "confidence": 0.95,
  "tags": ["auth", "api", "database"]
}
```

Full schema: [schema.json](schema.json)

## Storage Layers

| Layer | Role | Search |
|-------|------|--------|
| MemPalace | Primary semantic search + knowledge graph | `mempalace_search` |
| Filesystem | Backup, git-tracked | `grep`, `jq` |

## Configuration

Control via `.doit/config.yaml`:

```yaml
knowledge:
  enabled: true              # Enable/disable
  auto_extract: true         # Auto-extract at Phase 9.5
  require_confirmation: true # Ask user before saving
  extract_failed: true       # Also extract failed sessions
  max_records: 1000          # Max records per project
  layers:                    # Which layers to use
    mempalace: true
    filesystem: true
```

## Graceful Degradation

Works with any combination of memory tools:
- **Full stack**: MemPalace + Filesystem → best search quality
- **Partial**: Any subset → still works, uses available layers
- **None**: Filesystem only → basic grep-based search

## Manual Commands

```bash
# Extract knowledge from current session (manual trigger)
/doit-learn extract

# Inject knowledge for current request
/doit-learn inject "<request>"

# Migrate historical data
/doit-learn migrate

# View knowledge base statistics
/doit-learn stats

# Search knowledge base
/doit-learn search "<query>"
```

## Quality Guidelines

**Extract when:**
- Meaningful code changes with clear rationale
- Key decisions with trade-offs documented
- Errors resolved with root cause analysis
- Code patterns created for reuse

**Skip when:**
- Trivial changes (typos, formatting)
- No meaningful decisions or patterns
- User explicitly requests skip
- Session failed without learning value

## File Structure

```
learn/
├── SKILL.md          # This file — skill definition
├── extract.md        # Phase 9.5.5 extraction logic
├── inject.md         # Phase 1/2 injection logic
├── migrate.md        # Historical data migration
└── schema.json       # Knowledge record JSON schema
```

## Integration Points

**With doit-skill:**
- Phase 9.5.5 hook (after completion summary)
- Phase 1 hook (before grill questions)
- Phase 2 hook (before impact analysis)

**With memory tools:**
- MemPalace: Primary semantic search + knowledge graph
- Tokensave: Code pattern references

**With skill-creator:**
- Eval framework for testing extraction/injection quality
- Iterative improvement based on user feedback
