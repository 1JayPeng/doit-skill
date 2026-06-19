# Environment Detection (Phase -1) — Tool-Agnostic

**Writes detected environment to `[[CONFIG:main-instructions]]`.**

## Cache Check (Before Scanning)

Check if env cache exists and is valid (< 24h):
```bash
[ -f .doit/env-cache.json ] && [ .doit/env-cache.json -nt .git/HEAD ] && echo "CACHE-HIT" || echo "CACHE-MISS"
```

If cache hit → skip scanning, use cached values. If miss → run full detection.

## Detection Steps

### 1. Detect Project Type

```bash
# Detect project type from files
for marker in Cargo.toml package.json go.mod setup.py requirements.txt tsconfig.json; do
  [ -f "$marker" ] && echo "PROJECT_TYPE=$marker" && break
done
```

### 2-6. Scan environments, versions, lock files, Docker, system info

(Same detection scripts as before — these are shell commands, not tool-specific)

### 7. Determine Active Runtime + Conflict Detection

Determine which runtime is active and check for conflicts between version pins.

### 8. Write to `[[CONFIG:main-instructions]]`

Write detected environment section to `[[CONFIG:main-instructions]]`. If `## Environment` section exists, update it. If not, append.

```markdown
## Environment

**Detected:** 2026-06-16
**Project Type:** [type]
**Runtime:** [runtime info]
**Tools:** [tool availability]
```

### 8b-10. Inject Skill Loading, Background Task, Workflow Rules

Inject sections into `[[CONFIG:main-instructions]]` if not already present:
- Background Task Rules (use `[[SHELL:run]]` and `[[SCHEDULE:wakeup]]` syntax)
- Workflow Rules (phase gates, task management)
- Skill Loading (progressive disclosure)

**Note:** Adapter resolves `[[CONFIG:main-instructions]]` to actual filename (CLAUDE.md / AGENTS.md) and `[[SHELL:run]]`/`[[SCHEDULE:wakeup]]` to native tool calls.

### 11. Check External Tool Availability

Check each tool's availability:

```bash
echo "=== Tool Availability ==="

# Skill tools — check in [[CONFIG:skill-dir]]
for skill in doit grill-me tdd diagnose prototype handoff; do
  if [ -d "[[CONFIG:skill-dir]]/$skill" ]; then
    echo "  [OK]   $skill (project skill)"
  elif [ -d "[[CONFIG:global-skill-dir]]/$skill" ]; then
    echo "  [OK]   $skill (global skill)"
  else
    echo "  [MISS] $skill (skill)"
  fi
done

# External tools
for tool in rtk uv codegraph; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "  [OK]   $tool ($(command -v $tool))"
  else
    echo "  [MISS] $tool"
  fi
done

# MCP tools — check via [[CONFIG:mcp-config]]
# (MCP config check is tool-agnostic, uses filesystem)
```

**Per-tool fallback:**
| Tool | Unavailable → Fallback | Affected Phases |
|------|----------------------|-----------------|
| codegraph | `grep` + `find` | 2, 3, 5, 6, 7, 8 |
| context-mode | native shell (no auto-index) | 2, 3, 4, 7, 8 |
| tavily MCP | `[[WEB:search]]` | 1 |
| rtk | shell (no token opt) | all |
| mempalace | filesystem only (.doit/docs/) | -1, 1, 2, 3, 8 |

### 11b. MemPalace Health Check (if available)

If MemPalace MCP is available:
```
mempalace_status → check total_drawers, wings
mempalace_kg_stats → check entities, triples
```

### 12. Announce Detected Environment

Announce tool availability and any warnings.

### 13. Save Cache

Save env cache to `.doit/env-cache.json`.

### 14. Init .doit/config.yaml

Write `~/.doit/config.yaml` from user choices. Use `[[USER:ask]]` for interactive config:

```yaml
subagent:
  enabled: false
auto_commit:
  enabled: false
doc_capture:
  enabled: true
headroom:
  proxy:
    enabled: true
```

### 15. Cannot Determine Environment

If detection fails, announce warning and continue with defaults.
