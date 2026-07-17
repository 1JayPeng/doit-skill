# Historical Data Migration

## Purpose

Extract knowledge from existing git history, MemPalace, and worklog data to populate the knowledge base with historical sessions.

## When to Run

- First install of knowledge distillation module
- User explicitly requests historical data extraction
- After knowledge base corruption/loss

## Migration Sources

### Source 1: Git Commit History

Extract knowledge from commit messages and diffs:

```bash
# Get all feature/fix commits
git log --oneline --grep="feat:\|fix:" --since="2025-01-01" --format="%H|%s|%ad" --date=short

# For each commit, extract:
git show --stat <commit>                          # Files changed, +X/-Y
git diff <commit>^..<commit>                      # Actual changes
git log -1 --format="%b" <commit>                 # Commit body (rationale)
```

**Extraction logic:**
- **Commit type**: `feat:` → Type F, `fix:` → Type B, other → skip
- **Summary**: Commit subject line
- **Decisions**: Parse commit body for "Decision:" or "Rationale:" sections
- **Errors**: Parse commit body for "Fix:" or "Bug:" sections
- **Files changed**: From `git show --stat`
- **Lines added/removed**: From `git show --stat`

**Output format:**
```json
{
  "id": "<commit-hash>",
  "timestamp": "<commit-date>",
  "project": "<project-name>",
  "branch": "<branch-name>",
  "commit": "<commit-hash>",
  "type": "F",
  "status": "success",
  "summary": "<commit-subject>",
  "decisions": [...],
  "errors": [...],
  "files_changed": [...],
  "lines_added": N,
  "lines_removed": N,
  "confidence": 0.7,
  "tags": ["migrated", "git-history"]
}
```

### Source 2: MemPalace Knowledge Rooms

Extract from existing MemPalace knowledge rooms:

```
mempalace_list_drawers wing="<project>" room="knowledge_code" limit=100
mempalace_list_drawers wing="<project>" room="knowledge_api" limit=100
mempalace_list_drawers wing="<project>" room="knowledge_db" limit=100
mempalace_list_drawers wing="<project>" room="knowledge_flow" limit=100
```

**Extraction logic:**
- **Pattern**: Code pattern descriptions → code_patterns
- **API**: API discoveries → decisions
- **DB**: Database schemas → code_patterns
- **Flow**: Architecture decisions → decisions

**Output format:**
```json
{
  "id": "<mempalace-drawer-id>",
  "timestamp": "<drawer-created-at>",
  "project": "<project-name>",
  "type": "F",
  "status": "success",
  "summary": "<drawer-content-summary>",
  "code_patterns": [
    {"pattern": "<drawer-content>", "context": "<room-type>"}
  ],
  "confidence": 0.8,
  "tags": ["migrated", "mempalace"]
}
```

### Source 3: Worklog Data

Extract from `.doit/worklog.json`:

```bash
cat .doit/worklog.json 2>/dev/null
```

**Extraction logic:**
- **Phase entries**: Group by session (date + branch)
- **REQs**: Extract REQ-xxx items
- **Decisions**: Parse decision fields
- **Errors**: Parse error fields
- **Duration**: Calculate from timestamps

**Output format:**
```json
{
  "id": "<worklog-session-id>",
  "timestamp": "<worklog-date>",
  "project": "<project-name>",
  "branch": "<worklog-branch>",
  "type": "<worklog-type>",
  "status": "<worklog-status>",
  "summary": "<worklog-summary>",
  "reqs": ["REQ-001: ..."],
  "decisions": [...],
  "errors": [...],
  "duration_seconds": N,
  "confidence": 0.85,
  "tags": ["migrated", "worklog"]
}
```

## Migration Process

### Step 1: Scan for Available Sources

```bash
# Check git history
git log --oneline -1 2>/dev/null && echo "git: available" || echo "git: not available"

# Check MemPalace
mempalace_status 2>/dev/null && echo "mempalace: available" || echo "mempalace: not available"

# Check worklog
test -f .doit/worklog.json && echo "worklog: available" || echo "worklog: not available"
```

### Step 2: Extract from Each Source

For each available source, extract records using the source-specific logic.

### Step 3: Deduplicate

Compare extracted records:
- Same commit hash → merge into one record
- Same date + similar summary → merge
- Different sources, same event → combine information

### Step 4: Save to Knowledge Base

Save all extracted records to multi-layer storage (same as Phase 9.5 extraction).

### Step 5: Report

```
[KNOWLEDGE MIGRATION] Complete:
  Git commits: N extracted (M merged)
  MemPalace drawers: N extracted (M merged)
  Worklog entries: N extracted (M merged)
  Total unique records: X
  Saved to: mempalace ✓, filesystem ✓
```

## Configuration

Control migration via `.doit/config.yaml`:

```yaml
knowledge:
  migration:
    enabled: true              # Enable auto-migration on first run
    git_since: "2025-01-01"    # Only extract commits after this date
    max_commits: 100           # Max commits to extract
    mempalace_rooms:           # Which MP rooms to extract
      - knowledge_code
      - knowledge_api
      - knowledge_db
      - knowledge_flow
    worklog: true              # Extract from worklog
```

## Graceful Degradation

| Available Sources | Behavior |
|------------------|----------|
| Git + MemPalace + Worklog | Full migration |
| Git + MemPalace | Git + MemPalace migration |
| Git only | Git-only migration |
| MemPalace only | MemPalace-only migration |
| Worklog only | Worklog-only migration |
| None | Skip migration, report `[KNOWLEDGE MIGRATION] No sources available` |
