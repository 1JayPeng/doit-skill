# Do It — Do&nbsp;It Skill

Spec-driven, TDD-based development workflow for [Claude&nbsp;Code](https://github.com/anthropics/claude-code). Auto-classifies requests, grills ideas with internet search, enforces spec alignment, and ships nothing without tests.

[English](README.md) · [简体中文](README_ZH.md)

## Features

- **Auto-classify** — Distinguishes simple fixes, features, and bugs. Simple changes ship immediately; features go through the full pipeline.
- **Spec before code** — Grills ideas with internet research, generates acceptance criteria (REQ-001, REQ-002...). No code is written until the spec is agreed upon.
- **TDD enforced** — Each acceptance criteria goes through RED → GREEN → REFACTOR. No implementation without a failing test first.
- **E2E gate** — End-to-end tests in a real environment. Cannot be skipped, cannot be bypassed by the agent.
- **Review + Simplify** — Every change passes a mandatory review that removes duplication, dead code, and over-engineering. Ships lean code.
- **Git commit** — Phase 7 commits with meaningful messages, updates spec status. Feature branch ready for PR.
- **Resume mid-session** — Workflow spans multiple conversation turns. Type `/doit` again to pick up where you left off.

## How It Works

doit addresses a fundamental problem: **AI agents jump straight to implementation without thinking.** This produces code that looks correct but misses edge cases, has duplicated logic, or doesn't actually solve the stated problem.

doit inserts structured thinking between "user asks" and "agent codes":

```
User request → Classify → Spec (grill + REQ) → Plan (code graph)
       → Execute (TDD per REQ) → E2E (real env) → Review → Simplify → Commit
```

**Phase 0** — Classify the request. Simple change? Skip the ceremony, do it. Feature? Full pipeline. Bug? Route to diagnose.

**Phase 1** — Grill the idea. Internet search for existing solutions. Challenge assumptions. Generate acceptance criteria that are testable and specific.

**Phase 2** — Scan the codebase. What code will be affected? What are the community and symbol-level impacts?

**Phase 3** — Implement one REQ at a time. Test → Code → Refactor. Review and simplify after each REQ.

**Phase 4** — End-to-end tests in real environment. Not unit tests with `subprocess`. Real assertions on exit code, stdout, file output, database state.

**Phase 5–6** — Feature-level code review (OWASP security, architecture). Then simplify — remove duplication, flatten abstractions.

**Phase 7** — Git commit with meaningful message. Feature branch ready for merge.

## Table of Contents

- [Features](#features)
- [How It Works](#how-it-works)
- [Install](#install)
- [Usage](#usage)
- [Workflow Phases](#workflow-phases)
- [Mandatory E2E Gate](#mandatory-e2e-gate)
- [Dependencies](#dependencies)
- [Structure](#structure)
- [Adding Dependencies](#adding-dependencies)

---

## Install

### One-Line Installer (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh | bash
```

Installs doit-skill plus all dependencies (required + optional) automatically. Checks for existing installations.

```bash
# Skip optional skills and external tools
curl -fsSL https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh | bash -s -- --skip-optional

# Dry run (show what would be installed)
curl -fsSL https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh | bash -s -- --dry-run
```

### Via npx

```bash
npx skills add 1JayPeng/doit-skill
```

### From GitHub

```bash
# Clone and install
git clone https://github.com/1JayPeng/doit-skill.git
cd doit-skill
./scripts/install.sh

# Verify installation
./scripts/doctor.sh
```

### Dry Run

```bash
# See what would be installed
./scripts/install.sh --dry-run
```

### Update

```bash
# Pull latest changes
git pull
./scripts/install.sh
./scripts/doctor.sh
```

### Doctor

Check all dependencies:

```bash
./scripts/doctor.sh
```

**Output example**:

```
==========================================
  doit-skill Doctor
==========================================

[1/3] Checking doit skill installation...
  ✅ doit skill installed
  ✅ Core files present

[2/3] Checking bundled skills...
  ✅ grill-me installed
  ✅ tdd installed
  ...

[3/3] Checking optional skills...
  ℹ️  code-review not installed (optional)
  💡 Install: npx skills add code-review
  ...

[4/4] Checking external tools...
  ℹ️  context-mode not installed (recommended)
  💡 Install: npx @anthropic/context-mode
  ...

==========================================
  ✅ doit-skill Doctor complete!
==========================================
```

```bash
# Check all dependencies
./scripts/doctor.sh

# Output example:
# ✅ doit skill installed
# ✅ Core files present
# ✅ grill-me installed
# ✅ tdd installed
# ℹ️  context-mode not installed (recommended)
# 💡 Install: npx @anthropic/context-mode
```

## Usage

Any requirement statement auto-triggers the workflow:

```
> 我想要一个用户登录系统

[DOIT] Type: F (feature) -> Full workflow
[DOIT] Step 1: Tavily search for context...
[DOIT] Step 2: Grill session...
```

### Continuing the Workflow

A single `/doit` invocation may not complete the entire workflow — spec grilling, implementation, testing, and review are a long process. To continue from where you left off, simply type `/doit` again in the same conversation. The workflow picks up from the current phase (tracked in `.scratch/workflow-state.json`).

```
> /doit

[DOIT] Resuming from Phase 4 (E2E) — Phase 3 completed
[DOIT] Running E2E tests...
```

## Workflow Phases

| Phase | What | Tools Used |
|-------|------|------------|
| 0 | Classify request (S/F/B) | Built-in |
| 1 | Spec generation + grill | Tavily MCP, grill-me |
| 2 | Plan with code graph | code-review-graph, codegraph |
| 3 | Execute TDD + Review+Simplify | RTK, uv, pytest |
| 4 | E2E tests (mandatory) | Real env, HITL |
| 5 | Review + merge dupes | code-review, security-review |
| 6 | Review + Simplify (mandatory) | Built-in |
| 7 | Git commit | git |

## Mandatory E2E Gate

Phase&nbsp;4 (end-to-end testing) **cannot be skipped**. Three-layer defense prevents the agent from jumping straight from unit tests to review:

1. **Phase&nbsp;3 →&nbsp;4**: automatic transition when all REQs done. Agent must not ask user whether to skip E2E.
2. **SKILL.md gate**: Phase&nbsp;5 must not start until Phase&nbsp;4 produces `e2e: passed`.
3. **Review pre-flight gate**: Phase&nbsp;5 checks `.scratch/workflow-state.json` for `"e2e": "passed"` — hard block if missing.

### E2E Quality

Phase&nbsp;4 is **not** "unit tests with subprocess." It tests the user's full journey:

| Assert | Example |
|--------|---------|
| Exit code | `result.returncode == 0` |
| stdout/stderr | `result.stdout` |
| File output | `Path("out.txt").exists()` |
| Database state | `session.query(...).one()` |

E2E test levels:

| Level | What | Mode |
|-------|------|------|
| L0 | Required params, happy path | Auto |
| L1 | Boundary values | Auto |
| L2 | Conflicting param combinations | HITL |
| L3 | Fuzzy/random input, stability | HITL |

See [e2e.md](e2e.md) for details.

## Dependencies

doit-pack uses a **bundled dependency model** — core skills ship inside `skills/`. Optional skills and external tools require separate installation.

### Bundled Skills (ship with doit-pack)

| Skill | Purpose | Used In |
|-------|---------|---------|
| `grill-me` | Idea grilling | Phase 1 |
| `tdd` | TDD loop | Phase 3 |
| `diagnose` | Bug diagnosis | Phase 0 (type B) |
| `prototype` | Throwaway prototypes | Phase 1 (design exploration) |
| `handoff` | Session handoff | Any phase |
| `improve-codebase-architecture` | Architecture deepening | Phase 5 |

### Built-in Claude Code Skills (no install needed)

| Skill | Purpose |
|-------|---------|
| `code-review` | Code quality review |
| `security-review` | OWASP security audit |
| `verify` | Manual behavior verification |
| `caveman` | Token-compact mode |
| `find-skills` | Discover skills |
| `write-a-skill` | Create new skills |

### External Tools (user installs)

| Tool | Install | Used In |
|------|---------|---------|
| Context-Mode | `npx @anthropic/context-mode` | Phase 1-6 |
| RTK | `cargo install rtk` | Phase 3 |
| uv | `pip install uv` | Phase 3 |
| codegraph | `npx @anthropic/codegraph init` | Phase 2, 3 |
| code-review-graph | `pip install code-review-graph` | Phase 2 |
| Tavily MCP | Remote, API key only | Phase 1 |

## Structure

```
doit-skill/
├── SKILL.md          # Main entry point
├── classifier.md     # Request type detection
├── spec.md           # Phase 1: grill + REQ generation
├── plan.md           # Phase 2: code graph scan
├── execute.md        # Phase 3: TDD loop + Review+Simplify
├── e2e.md            # Phase 4: end-to-end testing
├── review.md         # Phase 5: code review
├── review-simplify.md # Phase 6: review + simplify
├── commit.md         # Phase 7: git commit
├── errors.md         # Failure handling
├── setup.md          # Install manifest
├── package.json      # Package metadata + dependencies
├── README.md         # This file (English)
├── README_ZH.md      # Chinese version
├── skills/           # Bundled skill dependencies
├── scripts/          # Install and utility scripts
│   ├── install.sh    # Full install script
│   └── add-dependency.sh # Add a new skill dependency
└── tests/            # Skill self-tests (future)
```

## Adding Dependencies

### Add a bundled skill
```bash
./scripts/add-dependency.sh <skill-name> bundled
```

### Add an optional skill reference
```bash
# Edit package.json directly
"dependencies.optionalSkills": {
  "new-skill": "recommended"
}
```

### Add an external tool
```bash
# Edit package.json directly
"dependencies.tools": {
  "new-tool": "install-command"
}
```

