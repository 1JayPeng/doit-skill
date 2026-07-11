# Phase 9.5 — Completion Summary + Knowledge Extraction

**Before Phase 10, tell the user what was done.** Language: user's configured language (default: Chinese).

Must include: branch, commit hash, change summary, REQ delivery, actionable next steps.

### Knowledge Extraction (MANDATORY)

**[CALL] Execute ALL MCP tool calls:**
```
[CALL] ctx_shell("git diff --stat HEAD~1..HEAD")
[CALL] ctx_shell("git log -1 --format='%s'")
```

Extract knowledge per category (code, api, db, flow) → MemPalace + KG facts.

### Knowledge Distillation

**[LOAD] [../learn/extract.md](../learn/extract.md) — full extraction + multi-layer storage.**
