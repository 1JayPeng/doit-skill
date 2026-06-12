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
[DOIT] Phase 10: Session summary complete
```

No manual phase orchestration. No tool juggling. `/doit` dispatches every phase, calls every tool, and ships code.

[English](README.md) · [简体中文](README_ZH.md)

---

## Prerequisites

doit is a **workflow orchestrator** — it relies on specialized tools for each phase. All are installed automatically by the setup script, but understanding the stack helps troubleshoot:

| Layer | Tool | Role |
|-------|------|------|
| **Code graph** | [codegraph](https://github.com/colbymchenry/codegraph) | 精准代码图查询 — 跨语言 AST 符号查找，调用图，影响分析 |
| **Code analysis** | [tokensave](https://github.com/aovestdipaperino/tokensave) | 即时改动检测 + 高级分析 — 类型检查，死代码，复杂度，测试覆盖，代码编辑 |
| **Session context** | [context-mode](https://github.com/mksglu/context-mode) | Command output indexing, semantic search, token savings |

| **Cross-session memory** | [MemPalace](https://github.com/MemPalace/mempalace) | Specs, decisions, knowledge graph — survives restarts |
| **Token optimization** | [Headroom](https://github.com/nicholasgriffintn/headroom) | CCR (Compress-Cache-Retrieve) proxy compression — token savings |
| **Context optimization** | [lean-ctx](https://leanctx.com) | Lean context window management — token savings |
| **Token optimization** | [RTK](https://github.com/rtk-ai/rtk) | Auto-wraps Bash commands, saves 60-90% tokens |
| **Code review** | [code-review](https://github.com/anthropics/claude-code-plugins) | OWASP security, architecture review |
| **Brevity mode** | [caveman](https://github.com/JuliusBrussee/caveman) | Token-compact responses, commit messages |
| **Web search** | [Tavily MCP](https://tavily.com) | Internet research for spec grilling (optional) |
| **Skill creation** | [skill-creator](https://github.com/anthropics/skills) | Skill eval framework, iterative improvement |
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

### Four Major Principles

doit enforces four coding principles throughout the workflow, built into each phase's execution rules:

| Principle | What it prevents | Applied In |
|-----------|------------------|------------|
| **Think Before Coding** | Wrong assumptions, hidden confusion | Phase 1 grill — challenge assumptions before writing REQs |
| **Brevity First** | Over-engineering, bloated abstractions | Phase 3 minimal implementation, Phase 6 remove unnecessary code |
| **Surgical Edits** | Unrelated edits, touching working code | Phase 3 only modify planned files, Debug minimum change |
| **Goal-Driven Execution** | Vague success criteria, endless clarification | Phase 3 testable verification per REQ, Phase 7 compare against spec |

How each principle enforces itself:
- **Think Before Coding** → Phase 1 grill challenges every assumption. No code until spec is clear.
- **Brevity First** → Phase 6 (Review + Simplify) removes unnecessary abstractions, merges duplicates, reduces line count.
- **Surgical Edits** → Each phase only touches files identified by the plan. No drive-by refactoring.
- **Goal-Driven Execution** → Every REQ has testable verification. E2E loop compares actual output against spec REQs.

### Workflow Phases

| Phase | What | Tools |
|-------|------|-------|
| -1 | Detect project environment | Built-in |
| 0 | Classify request (R/S/F/B) | Built-in, caveman, mempalace |
| 1 | Spec generation + grill | Tavily MCP, grill-me, mempalace |
| 2 | Plan with code graph | codegraph + tokensave, mempalace |
| 3 | Execute TDD + Review+Simplify | RTK, uv, tokensave, context-mode |
| 4 | E2E tests (mandatory) | tokensave, context-mode |
| 5 | Code review | code-review, tokensave |
| 6 | Review + Simplify (mandatory) | tokensave |
| 7 | E2E Verification Loop | tokensave, context-mode |
| 8 | Git commit + Push | git |
| 9.5 | Completion Summary + Knowledge Extraction | mempalace |
| 9.5.5 | Knowledge Distillation (structured learning) | learn/, mempalace, context-mode |
| 10 | Session Summary | RTK, context-mode, headroom, mempalace |

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

### Five-Layer Memory

doit integrates five memory layers so context survives across sessions:

| Layer | Tool | What It Stores |
|-------|------|----------------|
| **Code graph** | CodeGraph | Precise AST-based symbols, call edges, cross-language — survives code changes |
| **Code analysis** | TokenSave | Immediate change detection, diagnostics, complexity, test coverage — survives code changes |
| **Session context** | Context-Mode | Command output, semantic search index — survives tool calls |
| **Cross-session** | MemPalace | Specs, decisions, knowledge graph, agent diary — survives restarts |
| **Token optimization** | Headroom | CCR (Compress-Cache-Retrieve) proxy compression — token savings |

**CodeGraph + TokenSave complementary:** CodeGraph provides precise code graph queries (callers/callees accurate, cross-language support), TokenSave provides immediate change detection (15ms indexing) and advanced static analysis (diagnostics, dead code, complexity, test coverage). Both run in parallel for cross-validation.

**MemPalace** (30 MCP tools, KG + semantic search, diary). Follows **read-write symmetry**: every phase that writes also reads back in subsequent runs. Phase 0 sweeps 10 parallel calls to reconstruct project context.

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

All external tools are installed by `setup.sh`. If a tool is missing, doit degrades gracefully.

#### RTK (Rust Token Killer)

Token-optimized CLI proxy — saves 60-90% tokens on all Bash commands. [GitHub](https://github.com/rtk-ai/rtk)

```bash
# 1. Install binary to $HOME/.local/bin/rtk
curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh

# 2. Add $HOME/.local/bin to PATH (install script does NOT do this)
export PATH="$HOME/.local/bin:$PATH"
# Persist for future shells:
grep -q 'export PATH=.*\$HOME/.local/bin' ~/.bashrc 2>/dev/null || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# 3. Initialize for Claude Code (installs hooks + RTK.md globally)
rtk init -g
```

#### Rust (required by TokenSave)

```bash
# Install via rustup (Tsinghua mirror for China)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
  | RUSTUP_DIST_SERVER=https://mirrors.tuna.tsinghua.edu.cn/rustup \
    RUSTUP_UPDATE_ROOT=https://mirrors.tuna.tsinghua.edu.cn/rustup/rustup \
    sh -s -- -y
source "$HOME/.cargo/env"

# Configure cargo mirror (USTC) — optional, speeds up downloads in China
mkdir -p ~/.cargo
cat > ~/.cargo/config.toml <<'EOF'
[source.crates-io]
replace-with = 'ustc'
[source.ustc]
registry = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"
EOF
```

#### TokenSave

Code graph MCP server — symbol lookup, impact analysis, call graphs. [GitHub](https://github.com/aovestdipaperino/tokensave)

```bash
# 1. Install (requires Rust)
cargo install tokensave

# 2. Configure for Claude Code
tokensave install --agent claude

# 3. Initialize in project
tokensave init
```

#### Context-Mode

Context window management — command output indexing, semantic search. [GitHub](https://github.com/mksglu/context-mode)

```bash
# Install as Claude Code plugin
claude plugin marketplace add mksglu/context-mode
claude plugin install context-mode@context-mode
```

#### Headroom

Context optimization — proxy compression + memory persistence. [GitHub](https://github.com/nicholasgriffintn/headroom)

```bash
# 1. Install via uv
uv tool install "headroom-ai[mcp,proxy]"

# 2. Register MCP server
headroom mcp install
```

#### lean-ctx

Context optimization — lean context window management with AI agent integration. [Website](https://leanctx.com)

```bash
# 1. Install binary
curl -fsSL https://leanctx.com/install.sh | sh

# 2. Verify
lean-ctx --version

# 3. Connect all AI tools
lean-ctx onboard
source ~/.bashrc
lean-ctx init --agent claude

# 4. Manual fallback (if step 3 doesn't configure Claude Code)
claude mcp add lean-ctx lean-ctx

# 5. Verify
lean-ctx doctor
```

After installation, usage rules appear at `~/.claude/rules/lean-ctx.md`.

#### MemPalace (memory layer)

Cross-session semantic memory — specs, decisions, knowledge graph, agent diary. [GitHub](https://github.com/MemPalace/mempalace)

```bash
# 1. Install plugin
claude plugin marketplace add MemPalace/mempalace
claude plugin install --scope user mempalace

# 2. Install CLI (optional, for mempalace init)
uv tool install mempalace

# 3. Initialize in project
mempalace init .
```

#### caveman

Brevity mode — token-compact responses, commit messages. [GitHub](https://github.com/JuliusBrussee/caveman)

```bash
# Install as Claude Code plugin
claude plugin marketplace add JuliusBrussee/caveman
claude plugin install caveman@caveman

# Install hooks (statusline badge)
npx -y "github:JuliusBrussee/caveman" --with-hooks --skip-skills

# Configure statusline in settings.json
# setup.sh does this automatically — it sets statusLine to caveman-statusline.sh
```

#### code-review

Code review — OWASP security, architecture review. [GitHub](https://github.com/anthropics/claude-code-plugins)

```bash
claude plugin install code-review
```

#### uv

Fast Python package manager. [GitHub](https://github.com/astral-sh/uv)

```bash
pip install uv
```

#### Tavily MCP

Internet search for spec grilling. [Tavily](https://tavily.com)

```bash
# Add to .mcp.json (requires API key):
claude mcp add --transport http tavily https://mcp.tavily.com/mcp/?tavilyApiKey=<your-key>
```

#### CodeGraph

Cross-language code graph — AST-based symbol lookup, call graphs, impact analysis. Fallback when TokenSave is unavailable. [GitHub](https://github.com/colbymchenry/codegraph)

```bash
# Install via npm
npm i -g @colbymchenry/codegraph

# Configure MCP server
codegraph install --yes

# Initialize in project
codegraph init -i
```

#### skill-creator

Skill creation and evaluation framework — iterative skill improvement with eval viewer. [GitHub](https://github.com/anthropics/skills)

```bash
# Install via npx skills CLI
npx skills add anthropics/skills@skill-creator

# Verify
npx skills list | grep skill-creator
```

Used by doit-skill's knowledge distillation module (Phase 9.5.5) to test and iterate on extracted knowledge patterns.

### Resume Mid-Session

A single `/doit` invocation may not complete the entire workflow. To continue from where you left off, simply type `/doit` again. doit determines the current phase from conversation context, git state, and spec files. MemPalace diary entries and KG facts provide cross-session recovery when filesystem state is insufficient.

---

## Recent Changes

**2026-06-07** — Knowledge distillation module (Phase 9.5.5):
- New `learn/` module: structured knowledge extraction at Phase 9.5.5
- Knowledge injection at Phase 1/2 — injects relevant past sessions before grill
- Historical data migration from git, mempalace, worklog
- Multi-layer storage: mempalace + context-mode + filesystem
- skill-creator integration for eval-driven skill improvement
- setup.sh: installs skill-creator via npx skills CLI

**2026-06-12** — MemPalace as sole memory layer:
- Removed AgentMemory (never actually used in practice)
- MemPalace is primary: semantic search + KG + diary
- setup.sh: Clean MemPalace installation without agentmemory
- doctor.sh: Checks MemPalace plugin + CLI

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
