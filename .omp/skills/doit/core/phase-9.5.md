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


### Context Compact (OMP, if context grew large)

If running under OMP and context has grown significantly during the workflow:

```
[SHELL:run command="omp compact"]
```

This is a mid-workflow compact — not the final one. It happens before Phase 10 to give a clean state for the summary output.

**Fallback:** If `omp compact` is not available → use `[[MEMORY:compress]]` (headroom_compress).
