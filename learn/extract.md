# Knowledge Extraction — Phase 9.5.5 Hook

**Trigger:** After Phase 9.5 Completion Summary, before Phase 10

## Purpose

Extract structured knowledge from the completed doit session for future reuse.

## Extraction Process

### Step 1: Gather Session Data

Collect all available information about what just happened:

```bash
# Git state
git log -1 --format="%H %s"                    # Last commit
git diff --stat HEAD~1..HEAD                   # Files changed, +X/-Y
git branch --show-current                       # Branch name

# Session state
cat .doit/worklog.json 2>/dev/null             # Work log entries
cat .spec/current.md 2>/dev/null               # Spec with REQs
cat .doit/grill-summary.json 2>/dev/null       # Grill decisions
```

### Step 2: Generate Knowledge Record

Using the gathered data, construct a knowledge record conforming to [schema.json](schema.json):

```json
{
  "id": "<uuid-v4>",
  "timestamp": "<now ISO-8601>",
  "project": "<dirname of project root>",
  "branch": "<git branch>",
  "commit": "<commit hash>",
  "type": "F|B|S",
  "status": "success|failed|partial",
  "duration_seconds": <calculated>,
  "summary": "<one-line from completion summary>",
  "reqs": ["REQ-001: ...", "REQ-002: ..."],
  "decisions": [
    {"question": "...", "choice": "...", "rationale": "..."}
  ],
  "errors": [
    {"error": "...", "root_cause": "...", "resolution": "..."}
  ],
  "code_patterns": [
    {"pattern": "...", "files": ["path/to/file"], "context": "..."}
  ],
  "files_changed": ["path1", "path2"],
  "lines_added": 100,
  "lines_removed": 50,
  "confidence": 0.95,
  "tags": ["auth", "api", "database"]
}
```

### Step 3: Present to User for Confirmation

Show the extracted record to the user and ask for confirmation/edits:

```
[KNOWLEDGE EXTRACTION] Session summary:
  Type: F (Feature)
  Status: success
  Duration: 45 min
  Summary: "Implemented JWT authentication with role-based access control"
  REQs: REQ-001 (login), REQ-002 (registration), REQ-003 (password reset)
  Decisions: JWT Stateless auth, Redis session store, Zod validation
  Errors: Command injection in add-dependency.sh (fixed)
  Patterns: Auth middleware, Role-based access control

[AskUserQuestion] Confirm knowledge extraction?
  Options:
  - Confirm and save (Recommended)
  - Edit before save
  - Skip this session
```

### Step 4: Save to Multi-Layer Storage

Once confirmed, save to primary layers:

**Layer 1: AgentMemory (Primary)**
```
memory_save content="<JSON record>" type="workflow" project="<project>" concepts="<tags>"
```

**Layer 2: MemPalace (KG + semantic backup)**
```
mempalace_kg_add subject="<project>" predicate="shipped" object="<feature>" valid_from="<today>"
mempalace_check_duplicate content="<summary>"   # Check for duplicates
mempalace_add_drawer wing="<project>" room="knowledge_distillation" content="<summary>"
```

**Layer 3: Filesystem (Backup)**
```bash
mkdir -p .doit/knowledge/
cp <record> .doit/knowledge/<date>-<project>-<short-id>.json
```

### Step 5: Report Extraction Status

```
[KNOWLEDGE EXTRACTION] Saved to:
  ✓ AgentMemory (primary)
  ✓ MemPalace (KG updated)
  ✓ Filesystem (.doit/knowledge/)
[KNOWLEDGE EXTRACTION] Total records: N (this project)
```

## Extraction Quality Guidelines

**Extract when:**
- Session completed successfully with meaningful code changes
- Key decisions were made with clear rationale
- Errors were encountered and resolved (learning value)
- Code patterns were created that could be reused

**Skip when:**
- Session was trivial (typo fix, single file rename)
- No meaningful decisions or patterns
- User explicitly requests skip
- Session failed without learning value

## Failed Session Extraction

For failed or partial sessions, still extract but mark appropriately:

```json
{
  "status": "failed",
  "summary": "Failed to implement X due to Y",
  "errors": [
    {
      "error": "Database migration conflict",
      "root_cause": "Concurrent migration attempts",
      "resolution": "Not resolved - session ended"
    }
  ],
  "confidence": 0.6,
  "tags": ["failed", "database", "migration"]
}
```

Failed sessions are still valuable — they teach what NOT to do. When injected later, they show warnings:

```
[KNOWLEDGE INJECTION] Warning: Similar approach failed in session 2026-06-03
  Error: Database migration conflict with concurrent attempts
  Lesson: Use migration locks or serialize migrations
```

## Graceful Degradation

| Available Tools | Behavior |
|----------------|----------|
| AgentMemory + MemPalace | AgentMemory primary + MemPalace KG + filesystem backup |
| AgentMemory only | AgentMemory save + filesystem backup |
| MemPalace only | MemPalace save + filesystem backup |
| None | Filesystem backup only (.doit/knowledge/) |

If all layers fail:
```
[WARN] Knowledge extraction failed — all layers unavailable. Record saved to .doit/knowledge/
```

## Configuration

Control extraction behavior via `.doit/config.yaml`:

```yaml
knowledge:
  enabled: true              # Enable/disable knowledge extraction
  auto_extract: true         # Auto-extract at Phase 9.5.5
  require_confirmation: true # Ask user before saving
  extract_failed: true       # Also extract failed sessions
  max_records: 1000          # Max records per project (cleanup oldest)
  layers:                    # Which layers to use
    agentmemory: true        # Primary
    mempalace: true          # KG + semantic backup
    filesystem: true         # Always
```
