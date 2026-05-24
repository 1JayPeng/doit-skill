---
name: doit
description: >
  Full spec-driven, TDD-based development workflow. Auto-classifies requests into
  simple/feature/bug, routes to correct flow, and enforces spec alignment through
  every step. Use when user states any requirement, feature request, or idea that
  involves writing or modifying code. Triggers on: "我想做", "帮我加", "我需要",
  "add feature", "implement", "I want to", "build", or any request that implies
  new functionality.
---

# Do It

Spec-driven TDD workflow. Every feature passes through 9 phases. Nothing ships without spec. Every change must pass Review + Simplify, E2E Verification, and git commit before proceeding.

## Prerequisites

See [setup.md](setup.md) for full tool/skill install manifest.

## Phase -1 — Detect Environment

**Absolute first step. Before anything else.** Detect the project's runtime, virtual env, and package manager. Write to CLAUDE.md if not already documented. Cannot determine → ask user, do not guess. See [env-check.md](env-check.md).

## Phase 0 — Classify Request

**First — enable caveman mode for the entire session.**
```
Skill skill="caveman"
```

Then auto-classify. Read [classifier.md](classifier.md). Three types:

- **S (simple)** — single file, rename, quick fix. Execute directly. Skip phases 1-6.
- **F (feature)** — new functionality, cross-module, user-facing. Run phases 1-8.
- **B (bug)** — something broken. Run debug workflow D0-D6. See [debug.md](debug.md).

**Classify, announce type to user, proceed. If user disputes type, use their type.**

## Phase 1 — Spec

Write spec. See [spec.md](spec.md). Grill user ideas ruthlessly. Internet search via Tavily MCP for brainstorming. Split into acceptance criteria (REQ-001, REQ-002...). Save to `.spec/current.md`.

## Phase 2 — Plan

Check code-review-graph AND codegraph. Map impact at community and symbol level. Produce implementation order. See [plan.md](plan.md).

## Phase 3 — Execute

TDD loop per acceptance criteria. See [execute.md](execute.md). Start each REQ with codegraph_context for code understanding. RTK for all shell commands. uv for Python. Context-Mode for context management. Interactive spec alignment after each TDD cycle. Per-REQ review+simplify built in. Full e2e happens after Phase 6.

## Phase 4 — E2E (initial)

End-to-end tests in real env. See [e2e.md](e2e.md). L0+L1 auto, L2+L3 HITL. Run after Phase 3 unit tests complete.

## Phase 5 — Review

Feature-level review. Merge duplicate logic. Minimal refactor. See [review.md](review.md).

## Phase 6 — Review + Simplify

Review what you wrote. Find duplicates, over-engineering, missed README updates. Simplify. See [review-simplify.md](review-simplify.md). **NEVER skip this step.** After this, enters Phase 7 E2E Verification loop.

## Phase 7 — E2E Verification Loop

Re-run e2e tests after Review + Simplify. Compare actual output against spec REQs (not just test assertions). If mismatch → fix code to match spec, not test to match code. Loop until e2e passes AND output matches spec. See [e2e.md](e2e.md) § E2E Verification Loop.

## Phase 8 — Commit

Stage changed files, commit with meaningful message, update spec status. See [commit.md](commit.md).

## Error Handling

See [errors.md](errors.md). Spec fail = discard. Execute fail = re-grill. Review fail = retain on branch.

## Persistence

Spec in git (`feature/xxx` branch). Runtime state in `.scratch/workflow-state.json`. Phase 7 commits all changes with feature branch ready for PR.

## Resume

Workflow spans multiple conversation turns. If `/doit` is called again mid-session, check `.scratch/workflow-state.json` and resume from current phase. Do not restart from Phase 0.
