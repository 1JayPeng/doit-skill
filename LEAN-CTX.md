<!-- lean-ctx-owned: PROJECT-LEAN-CTX.md v1 -->
# lean-ctx — Context Engineering Layer
<!-- lean-ctx-rules-v11 -->

## Tool Mapping (MANDATORY — use instead of native equivalents)
| Instead of | Use | Example |
|------------|-----|---------|
| Read/cat/head/tail | `ctx_read(path, mode)` | `ctx_read("src/main.rs", "full")` |
| Grep/rg/find | `ctx_search(pattern, path)` | `ctx_search("fn handle", "src/")` |
| Shell/bash | `ctx_shell(command)` | `ctx_shell("cargo test")` |
| Edit (when Read unavailable) | `ctx_edit(path, old, new)` | `ctx_edit("f.rs", "old", "new")` |
| Multi file read | `ctx_multi_read(paths, mode)` | `ctx_multi_read(["a.rs", "b.rs"], "signatures")` |
| Incremental diff | `ctx_delta(path)` | `ctx_delta("src/main.rs")` |
| LSP refactor | `ctx_refactor(action, path, line)` | `ctx_refactor("rename", "f.rs", 42)` |
| Architecture | `ctx_architecture(action)` | `ctx_architecture("overview")` |
| PageRank map | `ctx_repomap(path)` | `ctx_repomap("src/")` |
| Semantic search | `ctx_semantic_search(query)` | `ctx_semantic_search("auth flow")` |
| URL fetch | `ctx_url_read(url, mode)` | `ctx_url_read("https://...", "facts")` |
| Routes | `ctx_routes(path)` | `ctx_routes("src/api/")` |
| Session memory | `ctx_session(action)` | `ctx_session("wakeup")` |
| Knowledge | `ctx_knowledge(action)` | `ctx_knowledge("remember", key="x")` |
| Stats | `ctx_stats()` | `ctx_stats()` |

## ctx_read Mode Selection
| Goal | Mode | When |
|------|------|------|
| Edit this file | `full` | Before any edit |
| Understand API | `signatures` | Context-only, won't edit |
| Re-read after edit | `diff` | Post-edit verification |
| Re-read after edit (better) | `delta` | Incremental diff, ~98% savings |
| Large file overview | `map` | >500 lines, won't edit |
| Large file (max compress) | `aggressive` | >500 lines, ~90% savings |
| Task-relevant sections | `task` | ~85% savings, uses task desc |
| Cross-session reference | `reference` | ~80% savings, retains identifiers |
| Data/log files | `entropy` | ~70% savings, high-entropy sections |
| Specific region | `lines:N-M` | Know exact location |
| Unsure | `auto` | System selects optimal mode |

## Workflow (follow this order)
1. **Orient:** `ctx_repomap` for large codebases, `ctx_overview(task)` for unfamiliar tasks
2. **Architecture:** `ctx_architecture(action="overview")` for structure, `ctx_routes` for web projects
3. **Locate:** `ctx_search(pattern, path)` for exact text; `ctx_semantic_search(query)` for concepts
4. **Read:** `ctx_read(path, mode)` with appropriate mode. Batch with `ctx_multi_read(paths, mode)`.
5. **Edit:** `ctx_edit(path, old_string, new_string)` or native Edit if available
6. **Refactor:** `ctx_refactor(action="rename|references|definition|implementations")` via LSP
7. **Verify:** `ctx_delta(path)` (incremental diff) or `ctx_read(path, "diff")` + `ctx_shell("test command")`
8. **Record:** `ctx_knowledge(action="remember|pattern|feedback|relate")` for non-obvious findings
9. **External:** `ctx_url_read(url, mode="markdown|facts")` for web/PDF/YouTube

## Proactive (use without being asked)
- `ctx_repomap` — at session start for large codebases (PageRank importance map)
- `ctx_overview(task)` — at session start for orientation
- `ctx_architecture(action="overview")` — Phase 2 before code graph scan
- `headroom_compress` — when context grows large (at phase boundaries)
- `ctx_knowledge(action="wakeup")` — at session start to surface prior findings
- `ctx_session(action="budget")` — set token budget at session start
- `ctx_stats` — Phase 10 for precise token consumption stats

## Compression Bypass (only when compressed output hides needed detail)
`ctx_read(path, "lines:N-M")` → `ctx_read(path, "full")` → `ctx_shell(cmd, raw=true)`
Return to compressed defaults after one expanded retrieval.

## Risk Gate (before high-impact edits)
Before editing exported symbols, auth, DB schemas, or 3+ files: run `ctx_impact(action="analyze")`
and `ctx_callgraph(action="callers")` to confirm blast radius.

## Session
- **Start:** `ctx_session(action="status")` + `ctx_knowledge(action="wakeup")`
- **End:** `ctx_session(action="decision", content="what was done + next steps")`
- **On [CHECKPOINT]:** `ctx_session(action="task", value="current status")`

NEVER use native Read/Grep/Shell when ctx_* equivalents are available.
<!-- /lean-ctx -->
