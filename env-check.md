# Environment Detection (Phase -1)

**Runs before anything else.** Detect what language/runtime this project uses and how to run it correctly.

## Detection Steps

### 1. Detect Project Type

Run this detection script:

```bash
# Detect project type and environment in one call
echo "=== Package Files ==="
ls -1 pyproject.toml setup.py setup.cfg package.json requirements.txt go.mod Cargo.toml Gemfile tsconfig.json Rakefile mix.exs package-lock.json yarn.lock pnpm-lock.yaml uv.lock Pipfile Makefile Dockerfile docker-compose.yml .python-version 2>/dev/null | head -20

echo "=== Python Environment ==="
command -v python3 python 2>/dev/null
python3 -c "import sys; print(f'{sys.executable} ({sys.version})')" 2>/dev/null

echo "=== Virtual Env ==="
ls -d .venv venv env .env __env__ 2>/dev/null
[ -f .venv/bin/activate ] && echo "FOUND: .venv" || true
[ -f venv/bin/activate ] && echo "FOUND: venv" || true
[ -f uv.lock ] && echo "FOUND: uv.lock" || true
[ -f .python-version ] && cat .python-version

echo "=== Conda ==="
command -v conda 2>/dev/null
conda env list 2>/dev/null | head -10

echo "=== Node ==="
command -v node npm yarn pnpm bun 2>/dev/null
node --version 2>/dev/null
cat package.json | grep -E '"(engines|type|main)"' 2>/dev/null

echo "=== Shell/Env ==="
echo "VIRTUAL_ENV=$VIRTUAL_ENV"
echo "CONDA_DEFAULT_ENV=$CONDA_DEFAULT_ENV"
echo "CONDA_PREFIX=$CONDA_PREFIX"
echo "NODE_ENV=$NODE_ENV"
```

### 2. Determine Active Runtime

Based on detection results, determine:
- **Language**: Python / Node.js / Go / Rust / ...
- **Package manager**: pip / uv / npm / yarn / pnpm / ...
- **Virtual env**: .venv / venv / conda env name / none
- **Runtime**: python3 / uv run / node / ...

### 3. Verify CLAUDE.md

Check if the project's root `CLAUDE.md` already documents the environment:

```bash
grep -i "environment\|venv\|virtual\|python\|node\|activate\|runtime\|conda" CLAUDE.md 2>/dev/null
```

**If CLAUDE.md already has correct environment info:** skip to next step.
**If CLAUDE.md is missing or has wrong environment info:** write the detected environment.

### 4. Write to CLAUDE.md

If `CLAUDE.md` exists but doesn't mention environment, add an `## Environment` section:

```markdown
## Environment

- Language: Python 3.x
- Virtual env: .venv (activate with `source .venv/bin/activate`)
- Run commands through: uv run
```

If `CLAUDE.md` doesn't exist at the project root, create one with just the environment section.

### 4.5. Inject Background Task Rules into CLAUDE.md

Always inject this section after `## Environment`. If the project already has a similar "background task" section, skip. Check:

```bash
grep -i "background task\|run_in_background\|后台任务" CLAUDE.md 2>/dev/null
```

If no match found, inject:

```markdown
## Background Task Rules

Before running any background command (via `run_in_background`), apply these rules:

1. **Estimate runtime first** — how long should this command take? Set a timeout value that is **2x the estimated time**.
2. **Ensure output readability** — background tasks must write to files (stdout/stderr redirect) so results can be read after completion.
3. **Clear exit signal** — the task must have an obvious completion indicator (exit code, log line, etc.). If the task's exit condition is unclear or ambiguous, **do not run it in the background** — run it in the foreground with an explicit timeout instead.
4. **Timeout default** — when no specific estimate is available, use 300 seconds (5 minutes) as the default timeout.
```

**If config already has a Background Task Rules section:** skip. No overwrite.

### 5. Check External Tool Availability

Run this detection script to verify all doit-skill external tools are available:

```bash
echo "=== Tool Availability ==="

# Skill tools
for skill in doit grill-me tdd diagnose prototype handoff improve-codebase-architecture; do
  if [ -d "$HOME/.claude/skills/$skill" ]; then
    echo "  [OK]   $skill (skill)"
  else
    echo "  [MISS] $skill (skill)"
  fi
done

# External tools
for tool in rtk uv tokensave caveman; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "  [OK]   $tool ($(command -v $tool))"
  else
    echo "  [MISS] $tool"
  fi
done

# Context-Mode plugin
if [ -d "$HOME/.claude/plugins" ] && grep -rl "context-mode" "$HOME/.claude/plugins/" >/dev/null 2>&1; then
  echo "  [OK]   context-mode (plugin)"
else
  echo "  [MISS] context-mode (plugin)"
fi

# Tavily MCP
if grep -rl "tavily" "$HOME/.claude/settings.json" "$HOME/.claude/plugins/" "$HOME/.mcp.json" 2>/dev/null; then
  echo "  [OK]   tavily (MCP)"
else
  echo "  [MISS] tavily (MCP — needs API key)"
fi

# Claude Code plugins (code-review, skill-creator)
if [ -d "$HOME/.claude/skills/code-review" ] || grep -rl "code-review" "$HOME/.claude/plugins/" 2>/dev/null; then
  echo "  [OK]   code-review (plugin)"
else
  echo "  [MISS] code-review (plugin)"
fi
if [ -d "$HOME/.claude/skills/skill-creator" ]; then
  echo "  [OK]   skill-creator (skill)"
else
  echo "  [MISS] skill-creator (skill)"
fi

# MemPalace plugin
if grep -rl "mempalace" "$HOME/.claude/plugins/" 2>/dev/null; then
  echo "  [OK]   mempalace (plugin)"
else
  echo "  [MISS] mempalace (plugin)"
fi
```

**If tools are missing, announce warnings — do not block the workflow:**

```
[WARN] context-mode NOT available -> Phase 1-8 will use Bash + grep (no auto-index)
[WARN] tavily NOT configured -> Phase 1 will use WebSearch (built-in) for internet research
[WARN] tokensave NOT installed -> Phase 2-8 will use Agent Explore for codebase intelligence
[WARN] tokensave NOT installed -> Phase 5-6 will use git diff for review (no code graph)
[WARN] rtk NOT installed -> shell commands run without token optimization
[WARN] uv NOT installed -> Python commands will use pip instead of uv
[WARN] caveman NOT installed -> no terse mode (caveman skill)
[WARN] code-review NOT installed -> Phase 5 will use manual review only
[WARN] skill-creator NOT installed -> skill development not available
[WARN] mempalace NOT installed -> no cross-session semantic memory (specs, decisions, implementation notes)
```

**Per-phase fallback summary (reference for all phases):**

| Tool | Unavailable → Fallback | Affected Phases |
|------|----------------------|-----------------|
| tokensave | `Agent Explore` + `grep` + `find` | 2, 3, 5, 6, 7, 8 |
| context-mode | native Bash (no auto-index) | 2, 3, 4, 7, 8 |
| tavily MCP | `WebSearch` (built-in) | 1 |
| rtk | Bash (no token opt) | all |
| uv | `pip` + `python3 -m venv` | 3, 4, 7 |
| caveman | verbose mode (no terse output) | 0+ |
| code-review | manual review (tokensave tools) | 5 |
| skill-creator | manual skill development | skill dev |
| mempalace | filesystem only (.doit/docs/, .spec/archive/) | -1, 1, 2, 3, 8, resume |

Missing tools trigger fallback paths in each phase (see each phase's fallback instructions).

### 6. Cannot Determine Environment

**If detection finds nothing, or multiple conflicting signals:** stop and ask the user.

```
Cannot determine project environment. Found:
  - pyproject.toml (Python?) but no virtual env
  - package.json (Node?) but node not installed
  - conda env list empty

Which environment should I use for this project?
  1. Python with uv (create new .venv)
  2. Node.js (which package manager?)
  3. Conda (which environment name?)
  4. Other (please specify)
```

**Wait for user input. Do not guess.**

### 7. Announce Detected Environment

```
[ENV] Python 3.12 via uv (.venv)
[ENV] Run commands: uv run <command>
[ENV] CLAUDE.md: already has environment section, skipping
```

Or if written:

```
[ENV] Node.js 20.x via npm
[ENV] Run commands: npx <command>
[ENV] CLAUDE.md: wrote Environment section
```

### 8. Init .doit/config.yaml

Check if `.doit/config.yaml` exists:

```bash
if [ ! -f .doit/config.yaml ]; then
  mkdir -p .doit
  cat > .doit/config.yaml << 'EOF'
doc-capture:
  enabled: true
  mode: auto
  path: .doit/docs

commit:
  branch: branch
  feat_prefix: feat
  fix_prefix: fix
  refactor_prefix: refactor
EOF
fi
```

If `enabled` is false (user declined at install), write `doc-capture.enabled: false` instead.

**If config already exists:** skip. No overwrite.
