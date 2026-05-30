---
name: grill-me
description: Interview the user relentlessly about a plan or design. Always ask 12 questions in 3 rounds (4 per round), dynamically generated based on context. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
---

# Grill Me — 3-Round, 12-Question Interrogation

**Mandatory: 12 questions minimum, always. 3 rounds × 4 questions per round.**
No exceptions. Even if the user's request seems clear. Even for "simple" features.

## Pre-Round — Research First

Before asking questions, use **Tavily MCP** to research:
- Industry standards and best practices for the domain
- Known pitfalls, common failure modes
- Alternative approaches, trade-offs
- Benchmark data, performance characteristics

Use research findings to generate **dynamically relevant** questions, not generic templates.

## Round 1 — Context & Scope (Questions 1-4)

Understand the full picture. Focus areas:
- Core user value and problem statement
- Success criteria and measurable outcomes
- Scope boundaries (what's IN and OUT)
- Stakeholder impact (other teams, users, downstream)

## Round 2 — Technical Depth (Questions 5-8)

Challenge assumptions, expose hidden complexity. Focus areas:
- Technical approach and alternative strategies
- Edge cases, failure modes, boundary conditions
- Integration points, external dependencies
- Performance, scale, security, compliance

## Round 3 — Execution & Risk (Questions 9-12)

Plan the build, identify risks, optimize for speed. Focus areas:
- Fastest path to MVP, deferrable features
- Dependencies, blockers, data migrations
- Testing strategy (unit, E2E, canary)
- Rollback, recovery, kill switches

## Execution Rules

- Ask 4 questions per round via `AskUserQuestion` with `multiSelect: false`
- Questions are **dynamically generated** based on context + research, not fixed templates
- After each round, summarize user's answers before proceeding
- If user skips or gives incomplete answer → **追问 until answered**. Do not skip.
- If user's requirements contain contradictions or are unrealistic → **immediately point out**, pause, and ask for clarification
- Use user's language (if user writes in Chinese, ask in Chinese; technical terms stay in English)
- Save progress to `.doit/grill-state.json` after each round for cross-session resume

## Output

After all 12 questions complete, produce:
- **Clarified goal** — refined from Round 1 answers
- **Technical decisions** — captured from Round 2 answers
- **Risk register** — identified risks + mitigation from Round 3 answers
- **Full answer record** — all 12 Q&A pairs included in spec as decision rationale
- **Acceptance criteria** — REQ-001, REQ-002, ... with mixed format (REQ list + Gherkin scenarios)

## Post-Grill: Gap Check

After 12 questions, if AI identifies significant gaps in the spec, it may propose a **Round 4** with additional questions. User confirms before proceeding.

## Smart Mode for Simple Tasks

For Type S (simple) tasks, AI intelligently decides:
- Trivial change → skip grill entirely
- Minor feature → 4-question quick grill (1 round)
- Full feature → standard 12-question grill (3 rounds)

## Cross-Session Resume

Grill progress is saved to `.doit/grill-state.json`:
```json
{
  "round": 2,
  "answers": {
    "Q1": "...",
    "Q2": "..."
  },
  "questions": ["...", "..."]
}
```

On resume, load state and continue from where it left off.
