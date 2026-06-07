# Spec: Knowledge Distillation (知识沉淀)

**Created:** 2026-06-07
**Type:** Feature (F)
**Workflow:** Full pipeline

## Problem Statement

doit-skill 执行完每个 session 后，所有经验（决策、错误、解法、代码模式）都丢失了。下次遇到类似问题，重新走一遍试错流程，浪费 token 和时间。

## Goal

构建知识沉淀模块，自动从 doit 工作流中提取成功路径，并在 Phase 1/2 注入相关经验，加速后续开发。

## Design Decisions (from Grill)

| Decision | Choice | Why |
|----------|--------|-----|
| Data sources | Full auto extraction | Zero user operation, knowledge accumulates naturally |
| Reuse scenario | Phase 1+2 injection | Preventive reuse — avoid repeating mistakes before coding |
| Skill scope | doit-skill built-in module | Seamless integration, setup.sh auto-installs |
| Storage | Multi-layer (agentmemory + mempalace + context-mode + tokensave) | Each layer plays its strength |
| Extraction granularity | Session-level summary | Small storage, fast retrieval, 90% cases sufficient |
| Matching algorithm | Semantic similarity | Flexible, cross-project, existing tools support |
| Extraction timing | Phase 9.5 trigger | Seamless workflow, user already sees results |
| Failed sessions | Record with failure markers + root cause | Learn from failures, downgrade in search |
| Extractor architecture | Hook functions | Zero user operation, integrated with doit phases |
| Index format | Structured JSON | Searchable, aggregable, schema-evolvable |
| Matching performance | Real-time embedding | Accurate, existing tools support it |
| Data quality | Auto-extract + human confirmation | High quality, Phase 9.5 user review |
| MVP scope | **All phases** + multi-layer storage | User chose full scope over MVP |
| Migration | Historical data batch extraction | Full history, needs parsing scripts |
| Testing | Skill-creator eval | Quantifiable verification |
| Dependencies | Minimal + graceful degradation | Works in most environments |

## Acceptance Criteria

### REQ-001: Knowledge Extraction Schema

Define structured JSON schema for knowledge records:
```json
{
  "session_id": "uuid",
  "project": "project-name",
  "timestamp": "ISO-8601",
  "type": "F|B|S",
  "status": "success|failed|partial",
  "branch": "feat/...",
  "commit": "abc123",
  "duration_minutes": 30,
  "reqs": ["REQ-001: ...", "REQ-002: ..."],
  "decisions": [
    {"question": "...", "choice": "...", "rationale": "..."}
  ],
  "errors": [
    {"error": "...", "root_cause": "...", "resolution": "..."}
  ],
  "code_patterns": [
    {"pattern": "...", "files": ["..."], "context": "..."}
  ],
  "tools_used": ["tokensave", "mempalace", ...],
  "confidence": 0.85
}
```

### REQ-002: Phase 9.5.5 — Knowledge Extraction Hook

**Given** Phase 9.5 completion summary is shown to user
**When** Phase 9.5.5 triggers
**Then** system:
1. Reads session context (git diff, worklog, conversation summary)
2. Generates structured knowledge record per REQ-001 schema
3. Presents extraction summary to user: `[LEARN] Extracted N items (decisions: X, errors: Y, patterns: Z)`
4. User can confirm or edit via AskUserQuestion
5. Saves to multi-layer storage

### REQ-003: Multi-Layer Storage

**Given** a knowledge record is confirmed
**When** storage is triggered
**Then** saved to:
- **AgentMemory** (primary): Full record for semantic search
- **MemPalace**: Summary in `knowledge_distillation` room + KG facts
- **Context-Mode**: Indexed for session-level retrieval
- **Filesystem**: `.doit/knowledge/<session_id>.json` as backup

**And** if any layer unavailable → skip that layer, continue with others, log warning

### REQ-004: Knowledge Injection at Phase 1/2

**Given** Phase 1 (Spec) or Phase 2 (Plan) is starting
**When** knowledge injection hook fires
**Then**:
1. Search using user's request text as semantic query
2. Filter by project name
3. Apply time decay (recent sessions ranked higher)
4. Return top-3 most relevant past sessions
5. Inject into context as `[LEARN] Related past sessions:` with brief summaries

### REQ-005: Historical Data Extraction

**Given** the knowledge distillation module is installed
**When** first run (no existing `.doit/knowledge/` directory)
**Then** system offers to extract historical knowledge from:
- Git commit messages (feat/fix types)
- Existing MemPalace knowledge rooms
- `.doit/worklog.json` entries

**And** converts them to structured knowledge format

### REQ-006: Skill Integration with Skill-Creator

**Given** skill-creator is installed from `anthropics/skills@skill-creator`
**When** creating the knowledge distillation skill
**Then**:
1. Uses skill-creator eval framework
2. Tests extraction accuracy
3. Tests injection relevance
4. Tests storage reliability
5. Skill passes eval before doit-skill integration

### REQ-007: Graceful Degradation

**Given** some memory tools are unavailable
**When** knowledge extraction or injection runs
**Then**:
- Uses available tools: agentmemory > mempalace > filesystem
- Logs which layers were skipped
- Completes workflow without blocking
- If no memory tools → filesystem-only mode

## Implementation Order

1. REQ-001: Schema definition
2. REQ-006: Install skill-creator
3. REQ-002: Phase 9.5.5 extraction hook
4. REQ-003: Multi-layer storage
5. REQ-004: Phase 1/2 injection
6. REQ-005: Historical data extraction
7. REQ-007: Graceful degradation
8. Update SKILL.md, phases.md, setup.sh

## Out of Scope (MVP)

- Real-time extraction during phase execution (only Phase 9.5)
- Cross-project knowledge transfer (project-scoped for now)
- Automated quality scoring (manual confirmation in MVP)
- Knowledge graph relationships between sessions (future)
- UI dashboard for browsing knowledge (terminal-only)
