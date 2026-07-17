# Phase 2: Plan (Tool-Agnostic)

**[LOAD] [plan.md](plan.md) — full Phase 2 execution.**

## Phase 2 — Plan

After Phase 1 spec is complete, build execution plan before touching any code.

### Step 1 — Codegraph Context (MANDATORY)

```
[CALL] codegraph_context(task="<spec summary from .spec/current.md>")
```

Get project-wide map: relevant symbols, call relationships, file dependencies.
This is the same context built during Phase 0 classification — reuse it, don't re-query.

If codegraph unavailable → `ctx_overview(task="<spec summary>")` + `[[FILE:read]]` of entry points.

### Step 2 — Impact Analysis per REQ

For each REQ in `.spec/current.md`:

```
[CALL] codegraph_impact(symbol="<REQ-relevant-symbol>")
```

Determine:
- Which files does this REQ touch?
- Are there existing abstractions it should extend?
- What's the blast radius?

Group REQs by file overlap → identify parallelization opportunities.

### Step 3 — Dependency Graph & Execution Order

Build REQ dependency graph:
- REQ A depends on REQ B → B must execute before A
- No dependency → can execute in parallel (if subagent enabled)

Output: ordered list with parallel wave assignments.

**Type F, small (<3 REQs):** Sequential order, single developer.
**Type F, large (3+ REQs):** Wave schedule → Architect produces dependency graph, Developers execute per wave.

### Step 4 — Plan Document

Write plan to `.doit/plan.md`:

```markdown
## Phase 2 Plan

**Spec:** .spec/current.md
**REQs:** N total, M waves

### Wave Schedule
- Wave 1: REQ-001, REQ-002 (no dependencies)
- Wave 2: REQ-003 (depends on REQ-001)
- Wave 3: REQ-004, REQ-005 (no dependencies)

### File Map
- REQ-001: src/auth.rs, tests/auth_test.rs
- REQ-002: src/api.rs
- REQ-003: src/auth.rs (extends REQ-001)
```

### Phase 2 Gate

Before entering Phase 3, verify:
1. `.spec/current.md` exists with all REQs
2. `.doit/plan.md` written with wave schedule
3. Codegraph impact analysis completed for each REQ
4. No iron rule violations

**铁律：Phase 2 不完成 = 不创建分支 = 不能进入 Phase 3。没有计划就写代码 = 盲写 = 返工。**

**[CALL] After creating plan, announce to user: `[PLAN] Phase 2 complete — N REQs in M waves`**
