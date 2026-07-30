# Do It — Workflow Orchestrator for AI Coding Agents

**`/doit <what you want>`** — one command that turns a vague request into shipped code.

## What It Is

doit is a **workflow orchestrator** for AI coding agents. It solves one problem: AI agents jump straight to code without thinking. This produces code that looks correct but misses edge cases, duplicates logic, or doesn't solve the stated problem.

doit inserts **structured thinking** between "user asks" and "agent codes":

```
User → `/doit add auth`
         ├─ Phase 1: Grill (challenge assumptions, clarify spec)
         ├─ Phase 2: Spec (write requirements, acceptance criteria)
         ├─ Phase 3: Plan (design before code)
         ├─ Phase 4: TDD (test first, red-green-refactor)
         ├─ Phase 5: E2E (full user journey tests)
         ├─ Phase 6: Review + Simplify (OWASP, dedup, delete dead code)
         ├─ Phase 7: Commit (message, push)
         └─ Done
```

Every phase is **mandatory**. No skipping. Quality gates at each boundary.

## Distributions

| Platform | Install |
|----------|---------|
| **Claude Code** | `setup.sh --agent claude` |
| **OpenCode** | `setup.sh --agent opencode` |
| **Oh My Pi** | `setup.sh --agent omp` |
| **Codex CLI** | `setup.sh --agent codex` |
| **MCP (any agent)** | `setup.sh --agent mcp` |
| **Manual** | `curl -fsSL https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh \| bash` |
| **Update** | Re-run `setup.sh` — detects existing install, upgrades in place |

## Installation

**One line. All tools.**

```bash
curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh | bash
```

Installs doit-skill + all dependencies. Detects what's already installed. Re-run to update.

```bash
# Skip optional tools
curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh | bash -s -- --skip-optional

# Dry run (no changes)
curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/1JayPeng/doit-skill/master/scripts/setup.sh | bash -s -- --dry-run
```

**Alternative install:**

```bash
npx skills add 1JayPeng/doit-skill
```

### Verify Installation

```bash
./scripts/doctor.sh
```

Checks all tools, reports missing ones, and suggests fixes.

### Update

Re-run `setup.sh` — it detects existing installs and upgrades in place.

```bash
# From local repo
./scripts/setup.sh
# or with agent flag
./scripts/setup.sh --agent claude
```

### Distribution Model

- **GitHub** (`1JayPeng/doit-skill`) = distribution source
- **`~/.claude/skills/doit/`** (or `.opencode/skills/doit/` etc.) = local installation
- **Local dev repo** = development environment — push to remote to distribute

Changes flow: `Local Dev → git push → GitHub → setup.sh → ~/.claude/skills/doit/`

See [setup.md](setup.md) for dependency details.

## Features

### Automated Spec-to-Code Pipeline

7 mandatory phases enforce quality: **Grill → Spec → Plan → TDD → E2E → Review → Commit**. No phase can be skipped. Each phase has explicit gates (acceptance criteria, test pass, review approval) before the next begins.

### Multi-CLI, One Workflow

Same pipeline runs across Claude Code, OpenCode, Codex CLI, oh-my-pi, MiMo Code, and any MCP-supporting agent. Tool adapter auto-selected at install time.

### Graceful Degradation

| Severity | Missing Tool Behavior |
|----------|----------------------|
| **Critical** (context-mode, caveman, mempalace, headroom, codegraph) | Phase degrades or shows warning |
| **Optional** (rtk, uv, tavily, ponytail) | Phase skipped, pipeline continues |

No brittle dependency chain.

### Layered Memory (Five Layers)

| Layer | Tool | What It Stores |
|-------|------|----------------|
| Session | Context-mode | Command output, searchable knowledge base |
| Token optimization | RTK | Auto-compresses Bash commands, 60-90% savings |
| Connection memory | Headroom | Compress-Cache-Retrieve proxy |
| Cross-session memory | MemPalace | KG + semantic search, specs, decisions, agent diary |
| Task memory | AgentMemory | Task progress, completion status |

MemPalace provides 30 MCP tools with read-write symmetry: every phase that writes also reads back in subsequent runs. Phase 0 sweeps 10 parallel calls to reconstruct project context.

### Lazy-by-Default Philosophy

The **Ponytail** principle is baked into every phase: question whether code needs to exist, prefer stdlib, delete dead code, flatten unnecessary abstractions. Phase 6 (Review + Simplify) actively enforces this.

### Tool Registry (`tools.sh`)

Single sourceable bash registry (`scripts/tools.sh`) managing all external tools:

- **Metadata arrays**: tool IDs, names, criticality, fallback strategies
- **Cache I/O**: `tools_save_status` writes JSON cache after install; `tools_read_status` reads it
- **Display helpers**: `_tool_emoji` maps status → emoji; `_tool_check_cached` is cache-first with `command -v` fallback
- **Doctor integration**: `doctor.sh` uses cache-first checks, avoiding redundant `command -v` calls

Both `setup.sh` and `doctor.sh` source the same registry — no duplicated logic.

## How It Works

### Architecture

```
Remote (GitHub) ──push──→ setup.sh ──install──→ ~/.claude/skills/doit/
                              │                        │
                          tools.sh                 doctor.sh
                              │                        │
                     ┌────────┴────────┐        cache-first checks
                     ▼                 ▼              │
              Installer scripts   Cache I/O    tools_read_status
              (per tool)         (env-cache.json)    │
                                                      ▼
                                               graceful fallback
                                               to command -v
```

Changes flow: **Local Dev → git push → Remote (GitHub) → setup.sh → ~/.claude/skills/doit/**.

### Phases in Detail

| # | Phase | What | Tools | Gate |
|---|-------|------|-------|------|
| 0 | Context sweep | Reconstruct project state from memory | MemPalace, codegraph | All 10 parallel calls return |
| 1 | Grill | Challenge assumptions, clarify spec | deep-grill, Tavily (optional), MemPalace | Spec is unambiguous |
| 2 | Spec | Write requirements, acceptance criteria | MemPalace | All ACs testable |
| 3 | Plan | Design before code | codegraph | Plan reviewed |
| 4 | TDD | Test-first, red-green-refactor | RTK, Headroom | Tests pass |
| 5 | E2E | Full user journey tests | — | Tests pass |
| 6 | Review + Simplify | OWASP, dedup, delete dead code | code-review, Ponytail | No open findings |
| 7 | Commit | Message, push | caveman (commit format) | Pushed |

### E2E Verification Loop

Phase 6 rewrites code. Phase 7 re-runs all E2E tests to verify the rewrite didn't break behavior, then compares actual output against spec REQs. **Fix the code, never change the spec to match broken output.** Max 3 iterations, then escalate.

### Bundled Skills

Six skills ship inside `skills/`, installed with doit:

| Skill | Purpose | Used In |
|-------|---------|---------|
| `.iron-rules` | Mandatory workflow rules | All phases |
| `caveman` | Ultra-compressed communication | Phase 7 commit messages |
| `code-review` | Security, architecture, duplication review | Phase 6 |
| `context-mode` | Searchable session knowledge base | Phase 0, all ctx_* calls |
| `deep-grill` | 4-phase Socratic/First Principles interrogation engine | Phase 1 (primary) |
| `deep-grill-cn` | Chinese version of deep-grill | Phase 1 (CN users) |
| `grill-me` | Abbreviated Q&A for Type B/S tasks | Phase 1 fallback |
| `mempalace` | Cross-session semantic memory | Phase 0, 1, 2, 7 |
| `ponytail` | YAGNI-enforced simplification | Phase 6 |
### External Tools

All installed by `setup.sh`. Missing tools = graceful degradation, not failure.

| Tool | Role | Install | Fallback |
|------|------|---------|----------|
| [Context-Mode](https://github.com/mksglu/context-mode) | Context window management | `npm install -g context-mode` | Degraded |
| [RTK](https://github.com/rtk-ai/rtk) | Token-optimized CLI proxy | `npm install -g rtk` | Skip |
| [Headroom](https://github.com/headroomlabs-ai/headroom) | Proxy compression + memory | `npm install -g headroom` | Skip |
| [MemPalace](https://github.com/MemPalace/mempalace) | Cross-session semantic memory | `uv tool install mempalace` | Degraded |
| [Caveman](https://github.com/JuliusBrussee/caveman) | Brevity mode | Bundled skill | Skip |
| Code Review | OWASP security review | Bundled skill | Skip |
| [Tavily MCP](https://tavily.com) | Internet research | `pip install tavily-mcp` | Skip |
| [uv](https://github.com/astral-sh/uv) | Fast Python package manager | `curl -LsSf https://astral.sh/uv/install.sh \| sh` | Degraded |
| [CodeGraph](https://github.com/colbymchenry/codegraph) | AST code intelligence | `npm install -g @codegraph/codegraph` | Degraded |
| [Ponytail](https://github.com/DietrichGebert/ponytail) | YAGNI simplification | Bundled skill | Skip |

## Four Core Principles

| Principle | What It Prevents | Applied In |
|-----------|-----------------|------------|
| **Think Before Coding** | Half-baked code that doesn't solve the stated problem | Phase 1 grill, Phase 2 spec, Phase 3 plan |
| **Test Everything** | Undetected regressions, false confidence | Phase 4 TDD, Phase 5 E2E, Phase 7 re-verify |
| **Delete Over Add** | Bloat, dead code, unnecessary abstractions | Phase 6 review + simplify, Ponytail rules |
| **Graceful Degradation** | Brittle dependency chains, install failures | All phases, tools.sh criticality/fallback system |

## Structure

```
doit-skill/
├── scripts/
│   ├── setup.sh                # Installer — auto-detect CLI, install tools, cache writes
│   ├── doctor.sh               # Diagnostic — cache-first checks, per-agent report
│   ├── tools.sh                # Registry — metadata arrays, cache I/O, display helpers
│   ├── setup.ps1 / doctor.ps1  # Windows PowerShell equivalents
│   └── installers/             # Per-tool install scripts (7 files)
├── .omp/
│   └── skills/doit/scripts/    # Runtime copy (synced to ~/.claude/skills/doit/)
├── core/
│   └── env-check.md            # Doctor documentation with cache I/O reference
├── skills/                     # Bundled skills
│   ├── caveman/
│   ├── code-review/
│   ├── context-mode/
│   ├── mempalace/
│   └── ponytail/
├── setup.md                    # Full install documentation
└── README.md
```

## Resume Mid-Session

A single `/doit` invocation may not complete the entire workflow. Simply type `/doit` again — it determines the current phase from conversation context, git state, and spec files. MemPalace diary entries and KG facts provide cross-session recovery when filesystem state is insufficient.

## Adding Tools

### Add an external tool

1. Create `scripts/installers/install_<tool>.sh` with `install_<t>()`, `verify_<t>()`, `version_<t>()`
2. Register in `scripts/tools.sh`: add to `ALL_TOOLS`, `TOOL_NAMES`, criticality, fallback
3. `doctor.sh` uses it automatically via the registry loop

### Add a bundled skill

```bash
./scripts/setup.sh --add-skill <name> --repo <url>
```

[English](README.md) · [简体中文](README_ZH.md)
