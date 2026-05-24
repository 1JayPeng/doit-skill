# Do It — Do&nbsp;It Skill

Spec-driven, TDD-based development workflow for [Claude&nbsp;Code](https://github.com/anthropics/claude-code). Auto-classifies requests, grills ideas with internet search, enforces spec alignment, and ships nothing without tests.

[English](README.md) · [简体中文](README_ZH.md)

## Table of Contents

- [Install](#install)
- [Usage](#usage)
- [Workflow Phases](#workflow-phases)
- [Mandatory E2E Gate](#mandatory-e2e-gate)
- [Dependencies](#dependencies)
- [Structure](#structure)
- [Adding Dependencies](#adding-dependencies)

---

## Install

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

### Recommended Skills (install separately)

| Skill | Purpose |
|-------|---------|
| `code-review` | Code quality review |
| `security-review` | OWASP security audit |
| `verify` | Manual behavior verification |

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

