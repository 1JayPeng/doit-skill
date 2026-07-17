---
name: grill-me
description: Interview the user relentlessly about a plan or design. Ask 4+ questions (Type F) or 3+ (Type B), dynamically generated from uncertainty scan. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
---

# Grill Me — Uncertainty-Driven Questioning

**Mandatory: 4 questions minimum for Type F (feature), 3 for Type B (bug).**
Quality > quantity. 4 specific questions beat 12 generic ones. Each question must reference a specific detail from the user's request, explain why it matters, and provide concrete options.

## Core Assumption: User is Non-Technical

**The user knows WHAT they want but NOT HOW to build it.** They don't understand:
- Implementation complexity (what sounds simple may be hard, and vice versa)
- Technical trade-offs (performance vs cost, consistency vs availability)
- Edge cases (network failures, data corruption, concurrent access)
- Integration points (auth, permissions, rate limits, data migration)

**Implication:** Your job is to translate "I want X" into a buildable spec by surfacing every hidden assumption, protecting the user from their own blind spots, and clarifying scope before committing to implementation. Speak in domain terms, not technical jargon. Translate consequences into business impact.

## Step 0: Uncertainty Scan (internal, before generating questions)

List 3-5 things you're uncertain about in the user's request. Rate each 1-5 (5 = completely unclear). Generate questions only for items rated >= 3.

**Bias: Assume non-technical.** The user likely doesn't realize:
- What their request implies technically (rate everything +1 for hidden complexity)
- What edge cases matter (surface them proactively)
- What trade-offs exist (present them as business choices, not technical ones)

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

## Complexity Scan (internal, before asking questions)

**Rate the implementation difficulty of the user's request on a scale of 1-5:**
1. Trivial (single file change, well-understood pattern)
2. Simple (multi-file but straightforward, no unknowns)
3. Moderate (requires architecture decisions, external integrations)
4. Complex (multiple systems, data migration, performance concerns)
5. High-risk (security-sensitive, real-time, regulatory compliance)

**Why this matters:** A non-technical user may say "just add a button" without realizing it triggers a cascade of changes. Use this scan to:
- Calibrate the number of questions (higher complexity → more questions)
- Surface scope creep risks early (Q: "this involves X, Y, Z — want all or pick one?")
- Set realistic expectations (Q: "this is a 2-week project vs 2-day, want to scope?")

## Question Templates (adapt to context)

### Non-Technical User Templates

**Scope clarification:**
Don't ask: "What's the scope?"
Do ask: "When you say [user's words], that could mean [Option A: simpler] or [Option B: more comprehensive]. Which feels closer? No worries if unsure — I can recommend."

**Complexity awareness:**
Don't ask: "Do you understand the complexity?"
Do ask: "What you described sounds simple on the surface, but involves [X, Y, Z] behind the scenes. Two options: (A) deliver the full thing properly, (B) start with a simpler version that covers 80% of cases. Which fits better?"

**Edge case surfacing:**
Don't ask: "What are the edge cases?"
Do ask: "When [specific scenario from request] fails mid-operation, what should happen to [specific data/state]? The user didn't specify rollback behavior."

**Success criteria translation:**
Don't ask: "What are the success criteria?"
Do ask: "How will you know this is done? 'It works' isn't testable. Is it: the CLI returns exit code 0? The API returns 200? The file appears on disk?"

**Integration point surfacing:**
Don't ask: "Have you considered integration?"
Do ask: "This feature will interact with [existing system Y]. Should it use [existing approach] or introduce something new? Most teams stick with existing to keep things maintainable."

**User behavior modeling:**
Don't ask: "How will users interact with this?"
Do ask: "Walk me through a day where someone uses this. What's the first thing they do? What would make them frustrated?"

**Data sensitivity:**
Don't ask: "Is this data sensitive?"
Do ask: "If [the data this feature handles] leaked publicly, would that be a problem? This affects how we store and transmit it."

**Priority ranking:**
Don't ask: "What's the priority?"
Do ask: "You've mentioned [feature list]. If I could only deliver 2 of these first, which 2 would make the biggest difference?"

### General Templates

**Scope:**
Don't ask: "What's the scope?"
Do ask: "The request mentions [feature X] and [feature Y]. These are typically separate modules. Should this deliver both or pick one?"

## Anti-Patterns — questions that are NOT grilling

NEVER ask these. They are filler:
- "What are the requirements?" -> You should already know from the request
- "What technology should we use?" -> Check the codebase first
- "Is this the right approach?" -> Too vague, be specific
- "Any other concerns?" -> Catch-all, not a real question
- "Should we include X?" when X is obviously in scope -> Not probing

**Non-Technical User Traps:**
- "Should we use OAuth or API keys?" -> User doesn't know the difference. Instead: "Do you want users to log in with their existing Google/Apple account, or should the system create separate usernames/passwords?"
- "What database schema do you want?" -> User doesn't think in schemas. Instead: "What information do you need to store about each [user/item/order]?"
- "What error handling do you want?" -> User doesn't think in error codes. Instead: "When something goes wrong, should we retry automatically, ask the user what to do, or just log it and move on?"
- "What's the API contract?" -> User doesn't think in contracts. Instead: "What data should this feature show, and when should it be updated?"

Every question must include:
1. A specific detail from the user's request you're questioning
2. Why it matters — **explained in business impact**, not technical debt
3. At least 2 concrete options — **framed in outcomes**, not implementation details

## Execution Rules

- **ALWAYS call `[[USER:ask]]` first** — output the question with options. Do NOT skip to defaults without asking.
- Ask questions via `[[USER:ask]]` with `multiSelect: false`
- Questions are **dynamically generated** from uncertainty scan + research, not fixed templates
- After all questions, summarize user's answers before proceeding to spec
- If user skips or gives incomplete answer → **use the recommended default and continue**. Do not block the workflow.
- **Critical: `[[USER:ask]]` is MANDATORY for every grill question.** The user must see the options. Skipping the call = user never sees the question = the grill is useless.
- If user's requirements contain contradictions or are unrealistic → **immediately point out**, use `[[USER:ask]]` (non-interruptive) to clarify
- Use user's language (if user writes in Chinese, ask in Chinese; technical terms stay in English)
- Save progress to `.doit/grill-state.json` after grill for cross-session resume

**Non-Technical User Rules:**
- **Translate tech to outcomes:** Never ask "REST or GraphQL?" — ask "Do you need real-time updates, or is checking for new data when the page loads OK?"
- **Surface complexity the user can't see:** "Adding [seems simple] actually touches [X existing systems]. It'll take [N] separate features to get right. Want me to start with the most important part?"
- **Probe hidden assumptions:** Users say "just like [popular app]" — dig into what they actually need from that comparison, not the whole thing
- **Warn about data implications:** "This will store [user data]. Should it be encrypted? Who else besides you should have access?"
- **Scope protect:** "You've described [large scope]. Let's break it into V1 (core, 2 weeks) and V2 (nice-to-have, 1 month more). Does that make sense?"
- **Prioritize with the user:** When requirements are vague, rank what matters most: speed, quality, flexibility, cost, security — help the user understand trade-offs
- **Limit question count even for vague requests:** Vague requests from non-technical users might tempt you to ask 20 questions. Instead, batch related questions into single asks with clear options. 4 well-crafted questions > 20 scattered ones.

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
