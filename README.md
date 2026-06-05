# Do It — Do&nbsp;It Skill

**One command. Everything done.**

Type `/doit <what you want>` in Claude Code. doit handles the rest: spec, plan, TDD, E2E tests, review, simplify, commit, push.

```
> /doit I need a user authentication system

[DOIT] Type: F (feature) -> Full workflow
[DOIT] Phase 0: Classifying...
[DOIT] Phase 1: Grilling idea with internet research...
...
[DOIT] Phase 8: Committed + pushed to origin/feat/auth
[DOIT] Phase 10: Context compacted
```

No manual phase orchestration. No tool juggling. `/doit` dispatches every phase, calls every tool, and ships code.

[English](README.md) · [简体中文](README_ZH.md)

---

## Prerequisites

doit is a **workflow orchestrator** — it relies on specialized tools for each phase. All are installed automatically by the setup script, but understanding the stack helps troubleshoot:

| Layer | Tool | Role |
|-------|------|------|
| **Code graph** | [tokensave](https://github.com/aovestdipaperino/tokensave) | Symbol lookup, impact analysis, call graphs |
| **Session context** | [context-mode](https://github.com/mksglu/context-mode) | Command output indexing, semantic search, token savings |
| **Cross-session memory** | [MemPalace](https://github.com/MemPalace/mempalace) | Specs, decisions, knowledge graph — survives restarts |
| **Token optimization** | [RTK](https://github.com/rtk-ai/rtk) | Auto-wraps Bash commands, saves 60-90% tokens |
| **Code review** | [code-review](https://github.com/anthropics/claude-code-plugins) | OWASP security, architecture review |
| **Brevity mode** | [caveman](https://github.com/JuliusBrussee/caveman) | Token-compact responses, commit messages |
| **Web search** | [Tavily MCP](https://tavily.com) | Internet research for spec grilling (optional) |
| **Python** | [uv](https://github.com/astral-sh/uv) | Fast Python package manager |

**All tools degrade gracefully.** If a tool is missing, doit skips that step and continues with the remaining capabilities.

### Install

**One line. All tools.**

```bash
curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh | bash
```

Installs doit-skill + all dependencies. Detects what's already installed. Re-run to update.

```bash
# Skip optional tools
curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh | bash -s -- --skip-optional

# Dry run
curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh | bash -s -- --dry-run

# Verify
./scripts/doctor.sh
```

**Alternative install methods:**

```bash
# Via npx
npx skills add 1JayPeng/doit-skill
```

See [setup.md](setup.md) for details.

---

## Usage

**Everything starts with `/doit`.** One command covers all scenarios:

```
# New feature
> /doit Add user authentication with OAuth2

# Bug fix
> /doit The login page crashes when email is empty

# Simple change
> /doit Rename the config file to settings.yaml

# Resume (no argument)
> /doit
```

doit auto-classifies the request:

| Type | When | What Happens |
|------|------|-------------|
| **F (feature)** | New functionality, cross-module | Full pipeline: spec -> plan -> TDD -> E2E -> review -> simplify -> commit |
| **B (bug)** | Something broken | Debug workflow: diagnose -> regression test -> fix -> verify -> commit |
| **S (simple)** | Single file, quick fix | Execute directly, skip ceremony |
| **R (resume)** | No argument | Resume from where you left off |

### How It Works

doit addresses a fundamental problem: **AI agents jump straight to code without thinking.** This produces code that looks correct but misses edge cases, has duplicated logic, or doesn't solve the stated problem.

doit inserts structured thinking between "user asks" and "agent codes":

```
User request -> Classify -> Spec (grill + REQ) -> Plan (code graph)
    -> Execute (TDD per REQ) -> E2E (real env) -> Review -> Simplify -> E2E verify -> Commit
```

Each phase is mandatory. Phases can't be skipped. The workflow enforces quality gates that prevent common failures:

| Gate | What it prevents |
|------|-----------------|
| Spec before code | Building the wrong thing |
| TDD per REQ | Code without tests |
| E2E after execute | Tests that pass but feature doesn't work |
| Review + Simplify | Duplication, over-engineering, dead code |
| E2E verify after simplify | Simplification breaking working code |
| Commit + Push | Lost work |

### Workflow Phases

| Phase | What | Tools |
|-------|------|-------|
| -1 | Detect project environment | Built-in, MemPalace |
| 0 | Classify request (R/S/F/B) | Built-in, caveman, MemPalace |
| 1 | Spec generation + grill | Tavily MCP, grill-me, MemPalace |
| 2 | Plan with code graph | tokensave, MemPalace |
| 3 | Execute TDD + Review+Simplify | RTK, uv, tokensave, context-mode, MemPalace |
| 4 | E2E tests (mandatory) | tokensave, context-mode |
| 5 | Code review | code-review, tokensave, MemPalace |
| 6 | Review + Simplify (mandatory) | tokensave |
| 7 | E2E Verification Loop | tokensave, context-mode |
| 8 | Git commit + Push | git, MemPalace |
| 9.5 | Completion Summary + Knowledge Extraction | MemPalace |
| 10 | Auto-Compact | RTK, context-mode, MemPalace |

### E2E Verification Loop

Phase 6 (Review + Simplify) rewrites code. Phase 7 re-runs all E2E tests to verify the rewrite didn't break behavior, then compares actual output against spec REQs. If output doesn't match spec, fix the code — never change the spec to match broken output.

```
Simplify done -> E2E tests -> Pass? -> Spec alignment -> Match? -> Commit
                       ↓                ↓               ↓
                      Fail           Fix code       Done
```

Max 3 iterations. After 3 failures, escalate to user.

### Review + Simplify (Mandatory)

Phase 5 reviews code for duplication, security vulnerabilities (OWASP Top 10), over-abstraction, and dead code. Phase 6 simplifies: merges duplicate logic, deletes dead code, flattens unnecessary abstraction layers, and reduces line count.

**Unreviewed code cannot be committed.** After simplification, Phase 7 re-runs all E2E tests to verify nothing broke.

### E2E Quality

Phase 4 tests the user's full journey — exit codes, stdout, file output, database state — not unit tests with `subprocess`.

| Level | What | Mode |
|-------|------|------|
| L0 | Required params, happy path | Auto |
| L1 | Boundary values | Auto |
| L2 | Conflicting param combinations | HITL |
| L3 | Fuzzy/random input, stability | HITL |

### Three-Layer Memory

doit integrates three memory layers so context survives across sessions:

| Layer | Tool | What It Stores |
|-------|------|----------------|
| **Code graph** | TokenSave | Symbols, call edges, dependencies — survives code changes |
| **Session context** | Context-Mode | Command output, semantic search index — survives tool calls |
| **Cross-session** | MemPalace | Specs, decisions, knowledge graph, agent diary — survives restarts |

MemPalace uses a **read-write symmetry** iron rule: every phase that writes data (specs, ADRs, implementation notes) also reads it back in subsequent runs. Phase 0 sweeps 10 parallel calls (diary, KG, knowledge rooms, sessions feedback) to reconstruct project context.

RTK auto-wraps every Bash command via PreToolUse hook, saving 60-90% tokens across all phases.

See [tool-integration-guide.md](tool-integration-guide.md) for per-phase tool call details.

### Bundled Skills

Six skills ship inside `skills/`, installed with doit:

| Skill | Purpose | Used In |
|-------|---------|---------|
| `grill-me` | Idea grilling | Phase 1 |
| `tdd` | TDD loop | Phase 3 |
| `diagnose` | Bug diagnosis | Debug D0 |
| `prototype` | Throwaway prototypes | Phase 1 |
| `handoff` | Session handoff | Any phase |
| `improve-codebase-architecture` | Architecture deepening | Phase 5 |

### External Tools

All external tools are installed by `setup.sh`. If a tool is missing, doit degrades gracefully:

| Tool | Install | Used In |
|------|---------|---------|
| TokenSave | `cargo install tokensave && tokensave install --agent claude` | Phase 2-7 |
| Context-Mode | `claude plugin marketplace add mksglu/context-mode` | Phase 3-7, 10 |
| MemPalace | `claude plugin install --scope user mempalace` | Phase -1, 0, 1, 2, 3, 5, 8, 9.5, 10 |
| RTK | `curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh \| sh` | All phases (auto-wrap) |
| caveman | `claude plugin marketplace add JuliusBrussee/caveman` | Phase 0+, 10 |
| code-review | `claude plugin install code-review` | Phase 5 |
| uv | `pip install uv` | Phase 3 |
| Tavily MCP | Remote, API key only | Phase 1 |

### Resume Mid-Session

A single `/doit` invocation may not complete the entire workflow. To continue from where you left off, simply type `/doit` again. doit determines the current phase from conversation context, git state, and spec files. MemPalace diary entries and KG facts provide cross-session recovery when filesystem state is insufficient.

---

## Recent Changes

**2026-06-04** — Workflow as iron rule — no phase can be skipped:
- New iron rule: "完整工作流不可跳过" — every phase mandatory, in order, no skipping
- New iron rule: "Review + Simplify 不可跳过" — unreviewed code cannot be committed

**2026-06-04** — MemPalace read-write symmetry integration:
- Iron rule: "MemPalace read-write symmetry" — MP calls same level as tokensave, mandatory when available
- Phase 0: embedded 10 parallel MP sweep calls (4 core + 4 knowledge rooms + 2 sessions feedback)

**2026-06-04** — Comprehensive code review fixes:
- Security: Fixed command injection vulnerability in `scripts/add-dependency.sh`
- Bug: Fixed `goto_step_9` bash syntax error in `env-check.md`

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
├── e2e.md            # Phase 4: end-to-end testing
├── review.md         # Phase 5: code review
├── review-simplify.md -> shared/review-simplify.md
├── commit.md -> shared/commit.md
├── errors.md         # Failure handling
├── shared/           # Shared phases (Feature + Debug)
│   ├── review-simplify.md
│   ├── e2e-verify.md
│   └── commit.md
├── skills/           # Bundled skill dependencies
│   ├── grill-me/     # Idea grilling
│   ├── tdd/          # TDD loop
│   ├── diagnose/     # Bug diagnosis
│   ├── prototype/    # Throwaway prototypes
│   ├── handoff/      # Session handoff
│   └── improve-codebase-architecture/
└── scripts/          # Install and utility scripts
    ├── setup.sh      # Full install
    ├── doctor.sh     # Dependency health check
    └── add-dependency.sh
```

## Adding Dependencies

### Add a bundled skill
```bash
./scripts/add-dependency.sh <skill-name> bundled
```

### Add an optional skill
```bash
# Edit package.json
"dependencies.optionalSkills": {
  "new-skill": "recommended"
}
```

### Add an external tool
```bash
# Edit package.json
"dependencies.tools": {
  "new-tool": "install-command"
}
```
