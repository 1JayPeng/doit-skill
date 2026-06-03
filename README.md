# Do It — Do&nbsp;It Skill

Spec-driven, TDD-based development workflow for [Claude&nbsp;Code](https://github.com/anthropics/claude-code). Auto-classifies requests, grills ideas with internet search, enforces spec alignment, and ships nothing without tests.

[English](README.md) · [简体中文](README_ZH.md)

## Features

- **Auto-classify** — Distinguishes simple fixes, features, and bugs. Simple changes ship immediately; features go through the full pipeline.
- **Spec before code** — Grills ideas with internet research, generates acceptance criteria (REQ-001, REQ-002...). No code is written until the spec is agreed upon.
- **TDD enforced** — Each acceptance criteria goes through RED → GREEN → REFACTOR. No implementation without a failing test first.
- **E2E gate** — End-to-end tests in a real environment. Cannot be skipped, cannot be bypassed by the agent.
- **Review + Simplify** — Every change passes a mandatory review that removes duplication, dead code, and over-engineering. Ships lean code.
- **Git commit** — Phase 8 commits with meaningful messages, updates spec status. Feature branch ready for PR.
- **Resume mid-session** — Workflow spans multiple conversation turns. Type `/doit` again to pick up where you left off.
- **Comprehensive env detection** — Phase -1 scans all virtual env types (conda/uv/venv/poetry/asdf/mise/nvm/...), version pins (.python-version/.node-version/.tool-versions/...), lock files (uv.lock/poetry.lock/package-lock.json/...), Docker/K8s, and system info. 24h cache, multi-env conflict detection. Writes to CLAUDE.md so future sessions start correct.

## How It Works

doit addresses a fundamental problem: **AI agents jump straight to implementation without thinking.** This produces code that looks correct but misses edge cases, has duplicated logic, or doesn't actually solve the stated problem.

doit inserts structured thinking between "user asks" and "agent codes":

```
User request → Env Detection → Classify → Spec (grill + REQ) → Plan (code graph)
       → Execute (TDD per REQ) → E2E (real env) → Review → Simplify → E2E Verify → Commit
```

**Phase -1** — Detect project environment. What language, what package manager, what virtual env. Write to CLAUDE.md if missing. Cannot determine → ask user.

**Phase 0** — Classify the request. Simple change? Skip the ceremony, do it. Feature? Full pipeline. Bug? Debug workflow (D0-D6) with regression test before fix.

**Phase 1** — Grill the idea. Internet search for existing solutions. Challenge assumptions. Generate acceptance criteria that are testable and specific.

**Phase 2** — Scan the codebase. What code will be affected? What are the community and symbol-level impacts?

**Phase 3** — Implement one REQ at a time. Test → Code → Refactor. Review and simplify after each REQ.

**Phase 4** — End-to-end tests in real environment. Not unit tests with `subprocess`. Real assertions on exit code, stdout, file output, database state.

**Phase 5–6** — Feature-level code review (OWASP security, architecture). Then simplify — remove duplication, flatten abstractions.

**Phase 7** — E2E verification loop. Re-run all e2e tests after simplify, then compare actual output against spec REQs. If output doesn't match spec, fix code. Loop until e2e passes AND output matches spec.

**Phase 8** — Git commit with meaningful message. Feature branch ready for merge.

## Table of Contents

- [Features](#features)
- [How It Works](#how-it-works)
- [Install](#install)
  - [One-Line Installer](#one-line-installer-recommended)
  - [Via npx](#via-npx)
  - [Local Development](#local-development)
  - [Doctor](#doctor)
- [Usage](#usage)
- [Workflow Phases](#workflow-phases)
- [Mandatory E2E Gate](#mandatory-e2e-gate)
- [Dependencies](#dependencies)
- [Tool Integration Guide](#tool-integration-guide)
- [Structure](#structure)
- [Adding Dependencies](#adding-dependencies)

---

## Install

### One-Line Installer (recommended)

```bash
curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh | bash
```

Installs doit-skill plus all dependencies automatically. Detects what's already installed.

```bash
# Skip optional skills and external tools
curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh | bash -s -- --skip-optional

# Dry run (show what would be installed)
curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh | bash -s -- --dry-run
```

**Update:** just re-run the same command.

### Via npx

```bash
npx skills add 1JayPeng/doit-skill
```

**Update:** npx skills will prompt to update.

### Local Development

```bash
# Clone and install
git clone https://v6.gh-proxy.org/https://github.com/1JayPeng/doit-skill.git
cd doit-skill
./scripts/setup.sh

# Dry run (preview before installing)
./scripts/setup.sh --dry-run

# Verify
./scripts/doctor.sh
```

**Update:** `git pull && ./scripts/setup.sh`

### Doctor

Check all dependencies (after installation or update):

```bash
./scripts/doctor.sh
```

---

## Usage

Any requirement statement auto-triggers the workflow:

```
> 我想要一个用户登录系统

[DOIT] Type: F (feature) -> Full workflow
[DOIT] Step 1: Tavily search for context...
[DOIT] Step 2: Grill session...
```

### Continuing the Workflow

A single `/doit` invocation may not complete the entire workflow — spec grilling, implementation, testing, and review are a long process. To continue from where you left off, simply type `/doit` again in the same conversation. The workflow picks up from the current phase (determined from conversation context and git/spec file state).

```
> /doit

[DOIT] Resuming from Phase 4 (E2E) — Phase 3 completed
[DOIT] Running E2E tests...
```

## Workflow Phases

| Phase | What | Tools Used |
|-------|------|------------|
| -1 | Detect project environment | Built-in, mempalace |
| 0 | Classify request (R/S/F/B) | Built-in, caveman, mempalace |
| 1 | Spec generation + grill | Tavily MCP, grill-me, mempalace |
| 2 | Plan with code graph | tokensave, mempalace |
| 3 | Execute TDD + Review+Simplify | RTK, uv, tokensave, context-mode, mempalace |
| 4 | E2E tests (mandatory) | tokensave, context-mode |
| 5 | Review + merge dupes | code-review, tokensave, mempalace |
| 6 | Review + Simplify (mandatory) | tokensave |
| 7 | E2E Verification Loop | tokensave, context-mode |
| 8 | Git commit + Push | git, mempalace |
| 9.5 | Completion Summary | mempalace |
| 10 | Auto-Compact | RTK, context-mode, mempalace |

## Mandatory E2E Gate

Phase&nbsp;4 (end-to-end testing) **cannot be skipped**. Three-layer defense prevents the agent from jumping straight from unit tests to review:

1. **Phase&nbsp;3 →&nbsp;4**: automatic transition when all REQs done. Agent must not ask user whether to skip E2E.
2. **SKILL.md gate**: Phase&nbsp;5 must not start until Phase&nbsp;4 produces `e2e: passed`.
3. **Review pre-flight gate**: Phase&nbsp;5 must verify all L0+L1 e2e tests passed before starting — hard block if not.

## Phase 7: E2E Verification Loop

**After simplify — verify, don't trust.** Phase 6 (Review + Simplify) rewrites code. Phase 7 re-runs all e2e tests to verify the rewrite didn't break user-facing behavior, then compares actual output against spec REQs to ensure output matches what the user asked for.

```
Phase 6 Review+Simplify done → Run E2E tests → Pass? → Spec alignment check → Match spec? → Commit
                                    ↓                        ↓                         ↓
                                   Fail                   No: fix code
                                                         to match spec
```

Max 3 loop iterations. After 3 failures, escalate to user with recommendation to revert Phase 6.

**Spec is ground truth.** When test output differs from spec, fix the code. Never change the spec to match a broken output.

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

doit uses a **bundled dependency model** — core skills ship inside `skills/`. Optional skills and external tools require separate installation.

### Bundled Skills (ship with doit)

| Skill | Purpose | Used In |
|-------|---------|---------|
| `grill-me` | Idea grilling | Phase 1 |
| `tdd` | TDD loop | Phase 3 |
| `diagnose` | Bug diagnosis | Debug workflow D0 |
| `prototype` | Throwaway prototypes | Phase 1 (design exploration) |
| `handoff` | Session handoff | Any phase |
| `improve-codebase-architecture` | Architecture deepening | Phase 5 |

### External Tools (user installs)

| Tool | Install | Used In |
|------|---------|---------|
| Context-Mode | `claude plugin marketplace add mksglu/context-mode` | Phase 3-7, 10 |
| RTK | `curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh` | All phases (auto-wrap) |
| uv | `pip install uv` | Phase 3 |
| Rust | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh` | Prerequisite for tokensave |
| tokensave | `cargo install tokensave && tokensave install --agent claude` | Phase 2-7 |
| caveman | `claude plugin marketplace add JuliusBrussee/caveman && claude plugin install caveman@caveman` (curl fallback) | Phase 0+ |
| code-review | `claude plugin install code-review` | Phase 5 |
| MemPalace | `claude plugin install --scope user mempalace` | Phase -1, 0, 1, 2, 3, 5, 8, 9.5, 10 |
| Tavily MCP | Remote, API key only | Phase 1 |

## Tool Integration Guide

doit integrates **8 external tools** across 10 workflow phases, forming a three-layer memory architecture. For a comprehensive per-phase breakdown of every tool call, specific commands, and design decisions — see [tool-integration-guide.md](tool-integration-guide.md).

**Three-layer memory:**
- **TokenSave** — code graph (symbols, call edges, dependencies)
- **Context-Mode** — session context (command output indexing, semantic search)
- **MemPalace** — cross-session semantic memory (specs, decisions, implementation notes)

**Token optimization:** RTK auto-wraps every Bash command via PreToolUse hook, saving 60-90% tokens across all phases.

## Structure

```
doit-skill/
├── SKILL.md          # Main entry point
├── env-check.md      # Phase -1: environment detection
├── classifier.md     # Request type detection
├── doc-capture.md    # Doc capture (pre-phase)
├── doit-config.md    # Config reference
├── spec.md           # Phase 1: grill + REQ generation
├── plan.md           # Phase 2: code graph scan
├── debug.md          # Debug workflow D0-D6 (Type B)
├── execute.md        # Phase 3: TDD loop + Review+Simplify
├── e2e.md            # Phase 4: end-to-end testing (P7 loop in shared/e2e-verify.md)
├── review.md         # Phase 5: code review
├── review-simplify.md -> shared/review-simplify.md # Phase 6: review + simplify
├── commit.md -> shared/commit.md        # Phase 8: git commit (shared with debug D6)
├── errors.md         # Failure handling
├── shared/           # Single source of truth for shared phases
│   ├── review-simplify.md   # Review+Simplify (used by Feature P6, Debug D4)
│   ├── e2e-verify.md        # E2E Verification Loop (used by Feature P7, Debug D5)
│   └── commit.md            # Commit (used by Feature P8, Debug D6)
├── setup.md          # Install manifest
├── tool-integration-guide.md  # Per-phase external tool usage guide
├── mempalace.md      # MemPalace integration across all phases
├── background-process.md      # Background process logging patterns
├── subagent.md       # Subagent orchestration patterns (native Claude Code Agent tool)
├── package.json      # Package metadata + dependencies
├── README.md         # This file (English)
├── README_ZH.md      # Chinese version
├── skills/           # Bundled skill dependencies
└── scripts/          # Install and utility scripts
    ├── setup.sh      # Full install script (curl or local)
    ├── doctor.sh     # Dependency health check
    └── add-dependency.sh # Add a new skill dependency
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

