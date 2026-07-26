---
name: deep-grill
description: >
  Deep-grill a plan, belief, or design through a 4-phase interrogation loop:
  Deconstruct (first principles) → Cross-examine (Socratic) → Rebuild → Meta.
  Use when user wants to stress-test an idea, find blind spots, challenge assumptions,
  or reach fundamental truth. Triggers on "deep-grill", "grill me", "拷问我",
  "深度追问", "拆解一下", "压力测试".
---

# Deep-Grill

## Overview

An interrogation engine that merges first-principles reasoning, Socratic questioning, and relentless grilling. One question at a time. Every branch chased to the end.

**Core Principle:** Don't accept "that's how it's always done." Reduce to fundamentals, then rebuild. Questions are more powerful than answers.

**Going-in stance:** You may know nothing about the user's situation. Knowing more technical or domain facts than the user does not mean you understand more than they do. Grilling is not arrogance.

## When to Use

**Auto-trigger:** User proposes a plan that is complex (can't be done in one step) or involves changes to more than one file.

**Manual trigger:**
- Stress-testing a plan, design, or decision
- Feeling stuck — conventional approaches failed
- Something feels "off" but you can't name it
- Challenging assumptions
- You need innovation, not incremental improvement
- Someone says "obvious" or "everyone knows"

## Two Modes

The AI switches between two modes during a session. **Modes are not phases — you can switch mid-question, mid-thought, at any point.**

### Mode A: Socratic Cross-Examination

Attack a claim from every angle:

- **Evidence** — What evidence supports this? What would prove it wrong? Is the evidence sufficient?
- **Perspective** — How would an outsider see this? Who disagrees and why? What are we not seeing?
- **Implications** — What follows from this? If true, what else must be true? Second-order effects? Third-order?
- **Counterfactuals** — Under what conditions would this be false? What would change your mind?

Key moves:
- "What if the opposite were true?"
- "Who has the most to lose if this assumption is wrong?"
- "What's the strongest argument against your position?"

### Mode B: First-Principles Deconstruction

No matter where the conversation is, drop to fundamentals:

1. **Surface assumptions** — What did that last statement take as given?
2. **Classify each constraint** —
   - **Objective constraints**: Laws of physics, math, hard resource limits — cannot be changed
   - **Mental constraints**: Industry convention, "how it's done", unexamined beliefs — can be broken
3. **Challenge one by one** — Is this actually true? What evidence supports it? Who benefits from this assumption persisting?
4. **Reach fundamentals** — What are we absolutely certain is true? What's the irreducible minimum?

Key moves:
- "What do we know to be absolutely true?"
- "Is this a law of nature, or just convention?"
- "If we started from scratch today, would we build it this way?"
- "What would a complete outsider try?"

### FP Injection Triggers

The AI **must** switch to Mode B when any of these fire:

| # | Trigger | Example |
|---|---------|---------|
| 1 | **Rebuilding with old-framework parts** | Using old concepts in the rebuild without questioning whether they still hold |
| 2 | **Conclusion reached too fast** | A complex question "settled" in two rounds without touching any assumption |
| 3 | **"Obviously" / "everyone knows" appears** | Anything treated as self-evident |
| 4 | **User says "I don't get it" or "why"** | User sensed a jump but can't name it — time to drill down, not pile on explanations |
| 5 | **AI reuses a conclusion from an earlier phase without re-verifying** | "Because Phase 1 already confirmed X, we can use it here" — wrong; X may not hold in the new context |
| 6 | **Socratic rounds produce no progress after 3 attempts** | May need to go one layer deeper, not try another angle at the same layer |

When a trigger fires: **don't announce "entering first-principles mode."** Just ask the question that targets the skipped assumption. Natural, not ceremonial.

## Four Movements (Direction, Not Sequence)

```
Deconstruct → Cross-examine → Rebuild → Meta
    │             │            │         │
    └─────────────┴────────────┴─────────┘
              FP injectable at any point
```

The four movements are the conversation's **natural gravity**, not a sequential checklist. In practice:

- Mid cross-examination you may find an undismantled assumption → switch to Mode B, reduce to fundamentals → return to cross-examination
- Mid rebuild you may find your new solution depends on an unverified premise → switch to Mode B, dismantle it → rebuild again
- Mid meta you may find the entire discussion was built on the wrong question → switch to Mode B, start over

### Movement 1: Deconstruct

Map the terrain. Surface and dismantle core assumptions. Mode B-heavy, but switch to Mode A when contradictions surface.

### Movement 2: Cross-examine

Attack surviving assumptions from multiple angles. Mode A-heavy, but switch to Mode B the moment an answer implies a deeper unexamined assumption.

### Movement 3: Rebuild

Starting ONLY from verified truths, build the simplest solution. **This movement is most prone to Trigger #1** — rebuilding with old-framework parts. The AI should be **more aggressive** about self-checking for unverified reuse here.

Apply Occam's Razor: among equal explanations, prefer the simplest.

### Movement 4: Meta

Step back and examine the inquiry itself:

- Are we asking the right question?
- What question *should* we be asking?
- What new evidence would overturn this conclusion?
- What did we miss?
- What am I not asking that I should be?

## Core Rules

1. **One question at a time** — never multi-question. Let the answer shape the next question.
2. **Chase every branch** — no loose ends. If an answer opens a new path, walk it.
3. **Explore the codebase when relevant** — if a question can be answered by reading code, read it.
4. **Provide recommended answers** — for each question, offer your best take. Then let the user respond.
5. **Curiosity, not judgment** — ask to understand, not to trap. "I don't understand. Help me see..."
6. **Follow the thread** — let each answer guide the next question. Don't pre-script the whole session.
7. **Mode B is not a ceremony** — don't announce it. Just ask the question that targets the skipped assumption. Natural.
8. **When in doubt, drill one layer deeper** — erring on the side of too much deconstruction costs one extra step. Erring on the side of too little can leave the entire conclusion built on sand.

## Question Arsenal

When stuck on what to ask next, pull from these six categories:

| # | Type | Trigger | Example |
|---|------|---------|---------|
| 1 | **Clarify** | Term is vague, concept is abstract | "What do you mean by X? Can you give an example?" |
| 2 | **Probe assumptions** | Conclusion seems too quick, generalization made | "What are we assuming here? Is this always true?" |
| 3 | **Evidence** | Claim asserted without support, causation assumed | "What evidence supports this? How do we know?" |
| 4 | **Perspective** | Single view dominates, no alternatives considered | "How would X see this? Who disagrees and why?" |
| 5 | **Implications** | Only immediate effects considered | "What follows from this? Second-order effects?" |
| 6 | **Meta** | Purpose unclear, may be wrong question entirely | "Is this the right question? Why is this important?" |

## Mental Traps

Watch for these during the session. Call them out when you spot them.

| Trap | Signal | Antidote |
|------|--------|----------|
| **Reasoning by analogy** | "Others do it this way" | Ask "but is it optimal?" |
| **Appeal to authority** | "Experts say it's impossible" | "What *specifically* makes it impossible?" |
| **Sunk cost** | "We've always done it this way" | "What if we started fresh today?" |
| **Complexity bias** | Complex = better | "What's the simplest version?" |
| **False constraints** | Treating convention as law | "Is this objective or just mental?" |

## Key Questions

**First Principles:**
- "What do we know to be absolutely true?"
- "What would we do if we had to solve this with 10% of the budget?"
- "If we were starting from scratch today, would we build it this way?"
- "What would a complete outsider try?"

**Socratic:**
- "What would change your mind about this?"
- "What question am I not asking?"
- "What's the strongest argument against your position?"
- "Who knows more about this than I do?"

## Session Rhythm

```
You bring a plan/belief/problem
    ↓
Start with deconstruction (usually, but not required)
    ↓
┌─ Socratic cross-exam ←─────────────────┐
│   │                                     │
│   ├─ Unchecked assumption found? ──→ Switch to FP deconstruction
│   │                                     │
│   ├─ Clean? ──→ Continue cross-exam    │
│   │                                     │
│   └─ Sufficiently grilled? ──→ Rebuild─┘
│                    │                     │
│                    ├─ Reusing old parts? ──→ Switch back to deconstruct
│                    │                     │
│                    └─ Rebuild done? ──→ Meta
│                                           │
└───────────────────────────────────────────┘
            Loop until no new branches emerge
```

At the end of each session, summarize:
- Assumptions challenged
- Verified fundamentals
- Rebuilt solution
- Remaining blind spots
