---
name: grill-me
description: Interview the user relentlessly about a plan or design. Ask 5+ questions (Type F) or 3+ (Type B), dynamically generated from uncertainty scan. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
---

# Grill Me — Uncertainty-Driven Questioning

**Mandatory: 5 questions minimum for Type F (feature), 3 for Type B (bug).**
Quality > quantity. 5 specific questions beat 12 generic ones. Each question must reference a specific detail from the user's request, explain why it matters, and provide concrete options.

## Step 0: Uncertainty Scan (internal, before generating questions)

List 3-5 things you're uncertain about in the user's request. Rate each 1-5 (5 = completely unclear). Generate questions only for items rated >= 3.

Example:
- "User said 'add auth' — unclear if OAuth, API key, or session-based" [5]
- "User said 'fast' — unclear if <100ms latency or <1s response time" [4]
- "User said 'store data' — unclear if SQLite, PostgreSQL, or file-based" [3]
- "User wants REST API — standard pattern, low uncertainty" [1] -> SKIP

## Step 1: Research First

Before asking questions, use **Tavily MCP** to research:
- Industry standards and best practices for the domain
- Known pitfalls, common failure modes
- Alternative approaches, trade-offs

Use research findings to generate **dynamically relevant** questions, not generic templates.

## Question Templates (adapt to context)

Don't ask: "What are the edge cases?"
Do ask: "When [specific scenario from request] fails mid-operation, what should happen to [specific data/state]? The user didn't specify rollback behavior."

Don't ask: "What's the scope?"
Do ask: "The request mentions [feature X] and [feature Y]. These are typically separate modules. Should this deliver both or pick one?"

Don't ask: "What are the success criteria?"
Do ask: "How will you know this is done? 'It works' isn't testable. Is it: the CLI returns exit code 0? The API returns 200? The file appears on disk?"

## Anti-Patterns — questions that are NOT grilling

NEVER ask these. They are filler:
- "What are the requirements?" -> You should already know from the request
- "What technology should we use?" -> Check the codebase first
- "Is this the right approach?" -> Too vague, be specific
- "Any other concerns?" -> Catch-all, not a real question
- "Should we include X?" when X is obviously in scope -> Not probing

Every question must include:
1. A specific detail from the user's request you're questioning
2. Why it matters (consequence of getting it wrong)
3. At least 2 concrete options for the user to choose from

## Execution Rules

- Ask questions via `[[USER:ask]]` with `multiSelect: false`
- Questions are **dynamically generated** from uncertainty scan + research, not fixed templates
- After all questions, summarize user's answers before proceeding to spec
- If user skips or gives incomplete answer → **use the recommended default and continue**. Do not block the workflow.
- If user's requirements contain contradictions or are unrealistic → **immediately point out**, use `[[USER:ask]]` (non-interruptive) to clarify
- Use user's language (if user writes in Chinese, ask in Chinese; technical terms stay in English)
- Save progress to `.doit/grill-state.json` after grill for cross-session resume

## Output

After all questions complete, produce:
- **Clarified goal** — refined from answers
- **Technical decisions** — captured from answers
- **Risk register** — identified risks + mitigation
- **Full answer record** — all Q&A pairs included in spec as decision rationale
- **Acceptance criteria** — REQ-001, REQ-002, ... with mixed format (REQ list + Gherkin scenarios)

## Post-Grill: Gap Check

After questions complete, if AI identifies significant gaps, it may propose additional questions. User confirms before proceeding.

## Type S (Simple) Tasks

For Type S (simple) tasks, grill can be abbreviated:
- Trivial change (rename, typo, single-line fix) → skip grill
- Minor change (config, small tweak) → 3-question minimum grill
- The grill minimum is NEVER waived for Type F or Type B.

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
