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

## Phase -1 — Detect Environment + Config

**Absolute first step. Before anything else.** Detect the project's runtime, virtual env, and package manager. Write to CLAUDE.md if not already documented. Cannot determine → ask user, do not guess.

Also init `.doit/config.yaml` if not present (default config for doc-capture, commit branch strategy). See [env-check.md](env-check.md) step 8 and [doit-config.md](doit-config.md).

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

**Before proceeding: check if user's prompt contains reference documentation.** If yes, capture it before any phase runs. See [doc-capture.md](doc-capture.md). Doc capture is independent of classification type (S/F/B) — always run first.

## Doc Capture (Pre-Phase)

If the user's prompt includes reference documents (API specs, business rules, conventions), save to `.doit/docs/`, verify tokensave index, and inject CLAUDE.md reference. This ensures future sessions can find the docs via tokensave search. See [doc-capture.md](doc-capture.md).

## Phase 1 — Spec

Write spec. See [spec.md](spec.md). Grill user ideas ruthlessly. Internet search via Tavily MCP for brainstorming. Split into acceptance criteria (REQ-001, REQ-002...). Save to `.spec/current.md`.

## Phase 2 — Plan

Check TokenSave code graph. Map impact at symbol and coupling level. Produce implementation order. See [plan.md](plan.md).

## Phase 3 — Execute

TDD loop per acceptance criteria. See [execute.md](execute.md). Start each REQ with tokensave_context for code understanding. RTK for all shell commands. uv for Python. Context-Mode for context management. Interactive spec alignment after each TDD cycle. Per-REQ review+simplify built in. Full e2e happens after Phase 6.

## Phase 4 — E2E (initial)

End-to-end tests in real env. See [e2e.md](e2e.md). L0+L1 auto, L2+L3 HITL. Run after Phase 3 unit tests complete.

## Phase 5 — Review

Feature-level review. Merge duplicate logic. Minimal refactor. See [review.md](review.md).

## Phase 6 — Review + Simplify

Review what you wrote. Find duplicates, over-engineering, missed README updates. Simplify. See [review-simplify.md](review-simplify.md). **NEVER skip this step.** After this, enters Phase 7 E2E Verification loop.

## Phase 7 — E2E Verification Loop

Re-run e2e tests after Review + Simplify. Compare actual output against spec REQs (not just test assertions). If mismatch → fix code to match spec, not test to match code. Loop until e2e passes AND output matches spec. See [shared/e2e-verify.md](shared/e2e-verify.md).

## Phase 8 — Commit + Push

Stage changed files, commit with meaningful message matching project's commit style, update spec status, and push to remote. See [commit.md](commit.md).

**Auto-push (no confirmation needed):** read `.doit/config.yaml` commit.branch:
- `branch` (default) — create `feat/...` or `fix/...` branch and push
- `current` — push current branch
- `none` — commit only, skip push

## Phase 9 — Cleanup

Remove all intermediate workflow files. See [commit.md](shared/commit.md) step 8.

- `.spec/current.md` — remove (archived in Phase 5)
- `.scratch/workflow-state.json` — remove (workflow complete)
- `.spec/doc-capture.md` — remove (temp file)
- `.scratch/` directory — remove if empty

**Keep:** `.spec/archive/`, `.doit/config.yaml`, `.doit/docs/`

## Error Handling

See [errors.md](errors.md). Spec fail = discard. Execute fail = re-grill. Review fail = retain on branch.

## Persistence

Spec in git (`feature/xxx` branch). Runtime state in `.scratch/workflow-state.json`. Phase 8 commits all changes and pushes to remote branch.

## Resume

Workflow spans multiple conversation turns. If `/doit` is called again mid-session, check `.scratch/workflow-state.json` and resume from current phase. Do not restart from Phase 0.

## Phase Gate Checklist — DO NOT SKIP

**After completing ANY phase, run this checklist before ending your response.** The conversation may continue, but the workflow MUST complete all phases. Code changes alone are NEVER the end of a doit session.

```
[Phase Gate] Type F flow (full):
  [x] Phase -1  Detect Environment + Config
  [x] Phase 0   Classify Request
  [x] Phase 1   Spec (grill → write → branch)
  [x] Phase 2   Plan (impact analysis)
  [x] Phase 3   Execute (TDD per REQ)
  [x] Phase 4   E2E (initial tests)
  [x] Phase 5   Review
  [x] Phase 6   Review + Simplify
  [x] Phase 7   E2E Verification Loop
  [x] Phase 8   Commit + Push
  [x] Phase 9   Cleanup intermediate files
  [x] Doc Capture (if user prompt has docs)

[Phase Gate] Type S flow (simple):
  [x] Phase 0   Classify
  [x] Execute directly
  [x] Doc Capture (if user prompt has docs)

[Phase Gate] Type B flow (bug):
  [x] Phase 0   Classify
  [x] D0-D6     Debug workflow (debug.md)
  [x] Phase 8   Commit + Push
```

**After Phase 3 completes:** always continue to Phase 4. Never stop at "tests pass, done."
**After Phase 6 completes:** always continue to Phase 7. E2E verification after simplification.
**After Phase 7 completes:** always continue to Phase 8. Every feature ships committed + pushed.
**After Phase 8 completes:** always continue to Phase 9. Clean up intermediate files.

**The only valid end state is Phase 9 clean.** If you're about to say "done" or "completed" and intermediate files are still present, you haven't finished.
