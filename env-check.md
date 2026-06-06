# Environment Detection (Phase -1)

**Runs before anything else.** Detect what language/runtime this project uses, how to run it correctly, and persist to CLAUDE.md.

## Cache Check (Before Scanning)

Before running full scan, check if cached results are still valid:

```bash
# Check env cache
CACHE_HIT=false
if [ -f .doit/env-cache.json ]; then
  cached_branch=$(python3 -c "import json; d=json.load(open('.doit/env-cache.json')); print(d.get('branch',''))" 2>/dev/null)
  current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
  cached_ts=$(python3 -c "import json; d=json.load(open('.doit/env-cache.json')); print(d.get('timestamp',''))" 2>/dev/null)

  if [ "$cached_branch" = "$current_branch" ] && [ -n "$cached_ts" ]; then
    age_hours=$(( ( $(date +%s) - $(date -d "$cached_ts" +%s 2>/dev/null || echo 0) ) / 3600 ))
    if [ "$age_hours" -lt 24 ]; then
      CACHE_HIT=true
      echo "[ENV] Cache hit (${age_hours}h old, branch: ${current_branch}). Skipping full scan."
    fi
  fi
fi
```

**Cache invalidation triggers:**
- Branch changed (git branch switch)
- Cache older than 24 hours
- `.doit/env-cache.json` deleted
- User explicitly requests re-scan

**Flow:**
- **If `CACHE_HIT=true`:** skip Steps 1-8 (detection), proceed to Step 9 (Background Rules).
- **If `CACHE_HIT=false` or missing:** run full scan (Steps 1-8), then Step 9.
- Always: Step 10 (Tool Availability) → Step 11 (Announce) → Step 12 (Save Cache, only if not cache hit).

## Detection Steps

### 1. Detect Project Type

```bash
echo "=== Package Files ==="
ls -1 pyproject.toml setup.py setup.cfg package.json requirements.txt go.mod Cargo.toml Gemfile tsconfig.json Rakefile mix.exs package-lock.json yarn.lock pnpm-lock.yaml uv.lock Pipfile Makefile Dockerfile docker-compose.yml .python-version .node-version .go-version .ruby-version .tool-versions .volta.json 2>/dev/null | head -30
```

### 2. Scan Virtual Environments (REQ-001)

```bash
echo "=== Virtual Environments ==="

# Python
echo "-- Python --"
ls -d .venv venv env .env __env__ 2>/dev/null
[ -f .venv/bin/activate ] && echo "FOUND: .venv (standard venv)" || true
[ -f venv/bin/activate ] && echo "FOUND: venv (standard venv)" || true
[ -f uv.lock ] && echo "FOUND: uv.lock -> uv package manager" || true
[ -f Pipfile ] && echo "FOUND: Pipfile -> pipenv" || true
[ -f poetry.lock ] && echo "FOUND: poetry.lock -> poetry" || true

# Conda
echo "-- Conda --"
command -v conda 2>/dev/null && echo "CONDA: available" || true
[ -f environment.yml ] && echo "FOUND: environment.yml -> conda env" || true
[ -f env.yml ] && echo "FOUND: env.yml -> conda env" || true
echo "CONDA_DEFAULT_ENV=$CONDA_DEFAULT_ENV"
echo "CONDA_PREFIX=$CONDA_PREFIX"

# Node.js
echo "-- Node.js --"
[ -d .nvm ] && echo "FOUND: .nvm (local nvm)" || true
command -v nvm 2>/dev/null && echo "NVM: available" || true
command -v fnm 2>/dev/null && echo "FNM: available" || true
command -f volta 2>/dev/null && echo "VOLTA: available" || true

# Ruby
echo "-- Ruby --"
command -v rvm 2>/dev/null && echo "RVM: available" || true
command -v rbenv 2>/dev/null && echo "RBENV: available" || true

# Go
echo "-- Go --"
command -v goenv 2>/dev/null && echo "GOENV: available" || true

# Universal version managers
echo "-- Universal --"
command -v asdf 2>/dev/null && echo "ASDF: available" || true
command -v mise 2>/dev/null && echo "MISE: available" || true
[ -f .tool-versions ] && echo "FOUND: .tool-versions -> asdf/mise" || true
[ -f .mise.toml ] && echo "FOUND: .mise.toml -> mise config" || true

# Flutter
echo "-- Flutter --"
command -v fvm 2>/dev/null && echo "FVM: available" || true
[ -f .fvm/fvm_config.json ] && echo "FOUND: .fvm -> Flutter Version Management" || true

# Rust
echo "-- Rust --"
command -v rustup 2>/dev/null && echo "RUSTUP: available" || true
[ -f rust-toolchain.toml ] && echo "FOUND: rust-toolchain.toml -> rustup toolchain" || true
[ -f rust-toolchain ] && echo "FOUND: rust-toolchain -> rustup toolchain" || true
```

### 3. Scan Version Pin Files (REQ-002)

```bash
echo "=== Version Pins ==="

# Python
[ -f .python-version ] && echo "PYTHON: $(cat .python-version)" || true
grep -m1 "requires-python" pyproject.toml 2>/dev/null && echo "  (from pyproject.toml)" || true

# Node.js
[ -f .nvmrc ] && echo "NODE: $(cat .nvmrc)" || true
[ -f .node-version ] && echo "NODE: $(cat .node-version)" || true
grep -m1 '"node"' package.json 2>/dev/null && echo "  (from package.json engines)" || true

# Go
grep -m1 "^go " go.mod 2>/dev/null && echo "  (from go.mod)" || true

# Ruby
[ -f .ruby-version ] && echo "RUBY: $(cat .ruby-version)" || true

# Rust
grep -m1 "rust-version" Cargo.toml 2>/dev/null && echo "  (from Cargo.toml)" || true

# Volta
[ -f .volta.json ] && cat .volta.json 2>/dev/null | head -10 || true

# asdf/mise
[ -f .tool-versions ] && cat .tool-versions 2>/dev/null || true
```

### 4. Scan Lock/Dependency Files (REQ-003)

```bash
echo "=== Lock Files ==="

# Python
[ -f uv.lock ] && echo "FOUND: uv.lock ($(wc -l < uv.lock) lines)" || true
[ -f poetry.lock ] && echo "FOUND: poetry.lock ($(wc -l < poetry.lock) lines)" || true
[ -f Pipfile.lock ] && echo "FOUND: Pipfile.lock" || true
[ -f requirements.txt ] && echo "FOUND: requirements.txt ($(wc -l < requirements.txt) lines)" || true
[ -d constraints ] && echo "FOUND: constraints/ (pip-compile)" || true
[ -f requirements/*.txt ] && echo "FOUND: requirements/*.txt" || true

# Node.js
[ -f package-lock.json ] && echo "FOUND: package-lock.json (npm)" || true
[ -f yarn.lock ] && echo "FOUND: yarn.lock" || true
[ -f pnpm-lock.yaml ] && echo "FOUND: pnpm-lock.yaml" || true

# Rust
[ -f Cargo.lock ] && echo "FOUND: Cargo.lock" || true

# Ruby
[ -f Gemfile.lock ] && echo "FOUND: Gemfile.lock" || true

# Go
[ -f go.sum ] && echo "FOUND: go.sum" || true

# Java
[ -f gradle.lockfile ] && echo "FOUND: gradle.lockfile" || true
[ -f build.gradle ] && echo "FOUND: build.gradle" || true
[ -f build.gradle.kts ] && echo "FOUND: build.gradle.kts" || true
[ -f pom.xml ] && echo "FOUND: pom.xml (Maven)" || true
[ -f mvn-dependency-tree.txt ] && echo "FOUND: mvn-dependency-tree.txt" || true
```

### 5. Scan Docker/K8s (REQ-004)

```bash
echo "=== Container ==="

# Docker
[ -f Dockerfile ] && echo "FOUND: Dockerfile" || true
[ -f Dockerfile.* ] && echo "FOUND: Dockerfile.* (multi-stage)" || true
ls -1 docker-compose*.yml docker-compose*.yaml 2>/dev/null && echo "  (compose files)" || true
[ -f .dockerignore ] && echo "FOUND: .dockerignore" || true
[ -d docker ] && echo "FOUND: docker/ directory" || true

# K8s
[ -f k8s.yml ] && echo "FOUND: k8s.yml" || true
[ -f kubernetes.yml ] && echo "FOUND: kubernetes.yml" || true
[ -d k8s ] && echo "FOUND: k8s/ directory" || true
[ -d kubernetes ] && echo "FOUND: kubernetes/ directory" || true
[ -f Chart.yaml ] && echo "FOUND: Chart.yaml (Helm)" || true
[ -f values.yaml ] && echo "FOUND: values.yaml (Helm)" || true

# Local clusters
command -v kind 2>/dev/null && echo "KIND: available" || true
command -v minikube 2>/dev/null && echo "MINIKUBE: available" || true
command -v k3s 2>/dev/null && echo "K3S: available" || true
command -v docker 2>/dev/null && echo "DOCKER: $(docker --version 2>/dev/null)" || true
command -v podman 2>/dev/null && echo "PODMAN: $(podman --version 2>/dev/null)" || true
```

### 6. Scan System Info (REQ-005)

```bash
echo "=== System ==="

# OS
uname -a 2>/dev/null | head -1
cat /etc/os-release 2>/dev/null | head -3

# Runtime
echo "=== Runtime ==="
command -v python3 python 2>/dev/null
python3 -c "import sys; print(f'{sys.executable} ({sys.version})')" 2>/dev/null
command -v node npm yarn pnpm bun 2>/dev/null
node --version 2>/dev/null
command -v go 2>/dev/null && go version 2>/dev/null
command -v rustc cargo 2>/dev/null && rustc --version 2>/dev/null
command -v ruby 2>/dev/null && ruby --version 2>/dev/null
command -v java 2>/dev/null && java --version 2>/dev/null
command -v gcc g++ 2>/dev/null && gcc --version 2>/dev/null | head -1
command -v swift 2>/dev/null && swift --version 2>/dev/null | head -1

# Arch
uname -m 2>/dev/null

# Shell
echo "SHELL=$SHELL"
echo "BASH_VERSION=$BASH_VERSION"
echo "ZSH_VERSION=$ZSH_VERSION"

# Virtual env vars
echo "VIRTUAL_ENV=$VIRTUAL_ENV"
echo "CONDA_DEFAULT_ENV=$CONDA_DEFAULT_ENV"
echo "CONDA_PREFIX=$CONDA_PREFIX"
echo "NODE_ENV=$NODE_ENV"
echo "PATH_DIRS=$(echo \$PATH | tr ':' '\n' | head -10)"

# Git hooks
[ -d .git/hooks ] && ls .git/hooks/ 2>/dev/null | grep -v '.sample' || true
command -v pre-commit 2>/dev/null && echo "PRE-COMMIT: available" || true
[ -f .pre-commit-config.yaml ] && echo "FOUND: .pre-commit-config.yaml" || true

# Editor config
[ -f .editorconfig ] && echo "FOUND: .editorconfig" || true
[ -f .clang-format ] && echo "FOUND: .clang-format" || true
[ -f .prettierrc ] && echo "FOUND: .prettierrc" || true
[ -f .eslintrc* ] && echo "FOUND: .eslintrc*" || true
[ -d .vscode ] && echo "FOUND: .vscode/ (VS Code settings)" || true
[ -d .idea ] && echo "FOUND: .idea/ (IntelliJ settings)" || true
```

### 7. Determine Active Runtime + Conflict Detection (REQ-008)

Based on all detection results, determine primary environment:

**Priority resolution (when no conflict):**
1. If only one language detected -> use it
2. If virtual env exists for that language -> use it
3. If lock file exists -> determine package manager from lock file name

**Conflict detection:** If multiple environments detected that could be primary, use `AskUserQuestion`:

```
AskUserQuestion:
  question: "Multiple environments detected. Which is your PRIMARY environment?"
  options:
    - label: "uv (uv.lock, .venv)"
      description: "uv package manager with .venv virtual env"
    - label: "conda (CONDA_PREFIX=/opt/conda)"
      description: "Conda environment with environment.yml"
    - label: "poetry (poetry.lock)"
      description: "Poetry with poetry.lock"
```

**铁律: Use AskUserQuestion, never stop and wait.** If user doesn't answer, pick the option with the strongest signal (lock file + venv > lock file alone > config file alone).

### 8. Write to CLAUDE.md (REQ-006)

Check if CLAUDE.md already has environment section:

```bash
grep -i "## environment\|## 环境" CLAUDE.md 2>/dev/null
```

**If CLAUDE.md already has correct environment section AND cache valid:** skip.
**If missing or stale:** write/update the section:

```markdown
## Environment

- **Language:** Python 3.12 (`.python-version`)
- **Package manager:** uv (`uv.lock` present)
- **Virtual env:** `.venv` (activate with `source .venv/bin/activate`)
- **Run commands:** `uv run <command>`
- **Docker:** `Dockerfile`, `docker-compose.yml` present
- **Detected:** 2026-06-01T12:00:00Z, branch: `master`
```

Include all detected layers that are relevant:
- Primary language + version source
- Package manager + lock file
- Virtual env type + activation
- Docker/K8s if present
- Secondary languages if detected
- Detection timestamp + branch (for cache reference)

**If CLAUDE.md doesn't exist:** create one with just the Environment section.

### 8b. Inject Skill Load Rules into CLAUDE.md

Ensure CLAUDE.md includes instructions to load caveman when doit runs. Check:

```bash
grep -i "skill load\|caveman.*doit\|load.*caveman" CLAUDE.md 2>/dev/null
```

If no match found, append after `## Environment` section:

```markdown
## Skill Load Rules

When the user invokes `/doit` (doit-skill), automatically load the caveman skill first:
- Call `Skill skill="caveman"` to enable terse mode for the entire session
- This runs before Phase 0 classification
- Caveman stays active until user explicitly disables it
```

**If CLAUDE.md already has a Skill Load Rules section:** skip. No overwrite.

### 9. Inject Background Task Rules into CLAUDE.md

Always inject this section after `## Environment`. If the project already has a similar "background task" section, skip. Check:

```bash
grep -i "background task\|run_in_background\|后台任务" CLAUDE.md 2>/dev/null
```

If no match found, inject:

```markdown
## Background Task Rules

**铁律：永远不要空等长时间任务。长对话中不例外。**

### 决策门控（每次运行 Bash 前必须判断）

运行任何命令前，估计执行时间：
- **<10s** → 前台 Bash（OK）
- **≥10s** → **必须**后台执行 + 完成信号
- **≥5min** → **必须** tmux + Monitor 或 ScheduleWakeup

### 执行规则

1. **Estimate runtime first** — how long should this command take? Set a timeout value that is **2x the estimated time**.
2. **Ensure output readability** — background tasks must write to files (stdout/stderr redirect) so results can be read after completion.
3. **Clear exit signal** — the task must have an obvious completion indicator (exit code, log line, etc.). If the task's exit condition is unclear or ambiguous, **do not run it in the background** — run it in the foreground with an explicit timeout instead.
4. **Timeout default** — when no specific estimate is available, use 300 seconds (5 minutes) as the default timeout.
5. **Mandatory polling** — every background task MUST have a corresponding Monitor or ScheduleWakeup. No polling = lost work.
6. **Continue working** — after launching a background task with monitoring, immediately continue with other work. Never idle-wait for the monitor.

### 禁止行为

- **禁止**运行长时间命令后不做任何其他操作（空等）
- **禁止**后台任务不设置完成信号（`[END]` 标记、Monitor、ScheduleWakeup）
- **禁止**用 `tail -f` 手动轮询（用 Monitor 或 ScheduleWakeup）
- **禁止**在长对话中忘记后台任务 → 用户问进度时立即检查 `.scratch/logs/` 和 `tmux list-sessions`
```

**If config already has a Background Task Rules section:** skip. No overwrite.

### 9b. Inject Workflow Rules into CLAUDE.md

Always inject this section after Background Task Rules. If the project already has a "Workflow Rules" section, skip. Check:

```bash
grep -i "workflow rules\|工作流铁律\|完整工作流" CLAUDE.md 2>/dev/null
```

If no match found, inject:

```markdown
## Workflow Rules

**铁律：工作流不是建议，是铁律。每个 phase 必须按顺序完成，不允许跳过。**

### 完整流程（Type F 功能）

```
Phase -1 → 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 9.5 → 10
环境检测  分类 规格 计划 执行 E2E 审查 简化 E2E验证 提交 清理 总结 压缩
```

### 禁止跳过

- **禁止**跳过 Phase 1（规格）直接写代码
- **禁止**跳过 Phase 4（E2E）直接进入审查
- **禁止**跳过 Phase 5-6（Review + Simplify）直接提交 — 没有审查不提交
- **禁止**跳过 Phase 7（E2E 验证）直接提交 — 简化后必须重新验证
- **禁止**跳过 Phase 8（Commit + Push）说"完成"
- **禁止**跳过 Phase 10（Compact）结束对话

### Phase 完成后必须继续

- Phase 3 完成 → 立即 Phase 4
- Phase 4 完成 → 立即 Phase 5
- Phase 5 完成 → 立即 Phase 6
- Phase 6 完成 → 立即 Phase 7
- Phase 7 完成 → 立即 Phase 8
- Phase 8 完成 → 立即 Phase 9
- Phase 9 完成 → 立即 Phase 9.5
- Phase 9.5 完成 → 立即 Phase 10

### Review + Simplify 不可跳过

每次代码变更后，必须经过 Review（Phase 5）和 Simplify（Phase 6）：
- Review：找重复代码、安全漏洞、过度抽象、死代码
- Simplify：合并重复、删除死代码、压平抽象、减少行数
- Simplify 后必须重新运行 E2E（Phase 7）

**唯一合法结束状态是 Phase 10 compact。**
```

**If config already has a Workflow Rules section:** skip. No overwrite.

### 10. Inject Skill Loading Rules into CLAUDE.md

Write or update `## Skill Loading` section in CLAUDE.md. This ensures caveman loads even if the agent skips SKILL.md Step 1. Check first:

```bash
grep -i "## skill loading\|## 技能加载" CLAUDE.md 2>/dev/null
```

If no match found, inject after `## Environment` section (or append if Environment section doesn't exist):

```markdown
## Skill Loading

**Mandatory: Always load doit skill for every task, every session, every command.** The doit workflow is the primary development framework for this project. Regardless of what the user asks, the doit skill must be loaded first.

Skills to load on every session:
- **doit** — spec-driven TDD workflow. **Always active, every task.** Load via `Skill skill="doit"` tool call at session start.
- **caveman** — terse response mode. Load via `Skill skill="caveman"` tool call. If unavailable, proceed in verbose mode.
```

**If CLAUDE.md already has a Skill Loading section:** skip. No overwrite.

### 11. Check External Tool Availability

Run this detection script to verify all doit-skill external tools are available:

```bash
echo "=== Tool Availability ==="

# Skill tools
for skill in doit grill-me tdd diagnose prototype handoff improve-codebase-architecture caveman; do
  if [ -d ".claude/skills/$skill" ]; then
    echo "  [OK]   $skill (project skill)"
  elif [ -d "$HOME/.claude/skills/$skill" ]; then
    echo "  [OK]   $skill (global skill)"
  else
    echo "  [MISS] $skill (skill)"
  fi
done

# External tools
for tool in rtk uv tokensave; do
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

# Claude Code plugins (code-review)
if [ -d "$HOME/.claude/skills/code-review" ] || grep -rl "code-review" "$HOME/.claude/plugins/" 2>/dev/null; then
  echo "  [OK]   code-review (plugin)"
else
  echo "  [MISS] code-review (plugin)"
fi

# MemPalace plugin
if grep -rl "mempalace" "$HOME/.claude/plugins/" 2>/dev/null; then
  echo "  [OK]   mempalace (plugin)"
else
  echo "  [MISS] mempalace (plugin)"
fi
```

### 11b. MemPalace Health Check (if available)

If MemPalace is available, run a quick health check:

```bash
# This is a MemPalace MCP call, not bash. Execute via tool:
# mempalace_status → check total_drawers, wings
# mempalace_kg_stats → check entities, triples
```

**If KG is empty (entities: 0):** announce `[WARN] MemPalace KG empty — Phase 8 MUST populate KG facts`
**If sessions wing > 80% of total drawers:** announce `[WARN] MemPalace sessions wing bloated — run mempalace_sync wing="sessions" to clean`

These warnings inform the agent to take corrective action during the workflow.

**If tools are missing, announce warnings — do not block the workflow:**

```
[WARN] context-mode NOT available -> Phase 1-8 will use Bash + grep (no auto-index)
[WARN] tavily NOT configured -> Phase 1 will use WebSearch (built-in) for internet research
[WARN] tokensave NOT installed -> Phase 2-8 will use grep + find + Read for codebase intelligence
[WARN] tokensave NOT installed -> Phase 5-6 will use git diff for review (no code graph)
[WARN] rtk NOT installed -> shell commands run without token optimization
[WARN] uv NOT installed -> Python commands will use pip instead of uv
[WARN] caveman NOT installed -> no terse mode (caveman skill)
[WARN] code-review NOT installed -> Phase 5 will use manual review only
[WARN] mempalace NOT installed -> no cross-session semantic memory (specs, decisions, implementation notes)
```

**Per-phase fallback summary (reference for all phases):**

| Tool | Unavailable → Fallback | Affected Phases |
|------|----------------------|-----------------|
| tokensave | `grep` + `find` + `Read` | 2, 3, 5, 6, 7, 8 |
| context-mode | native Bash (no auto-index) | 2, 3, 4, 7, 8 |
| tavily MCP | `WebSearch` (built-in) | 1 |
| rtk | Bash (no token opt) | all |
| uv | `pip` + `python3 -m venv` | 3, 4, 7 |
| caveman | verbose mode (no terse output) | 0+ |
| code-review | manual review (tokensave tools) | 5 |
| mempalace | filesystem only (.doit/docs/, .spec/archive/) | -1, 1, 2, 3, 8, resume |

Missing tools trigger fallback paths in each phase (see each phase's fallback instructions).

### 12. Announce Detected Environment

```
[ENV] Python 3.12 via uv (.venv)
[ENV] Run commands: uv run <command>
[ENV] CLAUDE.md: wrote Environment section
[ENV] Cache saved to .doit/env-cache.json (24h TTL)
```

Or if cache was used:

```
[ENV] Cache hit (12h old, branch: master)
[ENV] Python 3.12 via uv (.venv) - from cached scan
```

Or if written:

```
[ENV] Node.js 20.x via npm
[ENV] Run commands: npx <command>
[ENV] CLAUDE.md: wrote Environment section
```

### 13. Save Cache (REQ-007)

After successful scan and CLAUDE.md update, save cache:

```bash
mkdir -p .doit

# Ensure cache file is gitignored (local-only, never committed)
if ! grep -q "env-cache.json" .gitignore 2>/dev/null; then
  echo ".doit/env-cache.json" >> .gitignore
  echo "[ENV] Added .doit/env-cache.json to .gitignore"
fi

# Write cache
python3 -c "
import json, datetime
cache = {
    'branch': '$(git branch --show-current 2>/dev/null || echo unknown)',
    'timestamp': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'language': '<detected language>',
    'package_manager': '<detected manager>',
    'virtual_env': '<detected env>',
}
with open('.doit/env-cache.json', 'w') as f:
    json.dump(cache, f, indent=2)
print('[ENV] Cache saved to .doit/env-cache.json (24h TTL)')
" 2>/dev/null || echo "[ENV] Cache save skipped (python3 not available)"
```

### 14. Init .doit/config.yaml

Check if `.doit/config.yaml` exists:

```bash
if [ ! -f .doit/config.yaml ]; then
  mkdir -p .doit
  cat > .doit/config.yaml << 'EOF'
doc-capture:
  enabled: true
  mode: auto
  path: .doit/docs

subagent:
  enabled: false

commit:
  branch: branch
  feat_prefix: feat
  fix_prefix: fix
  refactor_prefix: refactor
EOF
fi
```

If `doc-capture.enabled` is false (user declined at install), write `doc-capture.enabled: false` instead.
If `subagent.enabled` is true (user opted in at install), write `subagent.enabled: true` instead.

**If config already exists:** skip. No overwrite. On update, show current config values.

### 15. Cannot Determine Environment

**If detection finds nothing, or multiple conflicting signals:** use `AskUserQuestion`:

```
AskUserQuestion:
  question: "Cannot determine project environment. What should I use?"
  options:
    - label: "Python with uv (Recommended)"
      description: "Create new .venv with uv"
    - label: "Node.js"
      description: "Use npm/yarn/pnpm"
    - label: "Conda"
      description: "Use conda environment"
    - label: "Other"
      description: "Specify manually"
```

**铁律: Use AskUserQuestion, never stop and wait.** If user doesn't answer, use the first option with the strongest file signal (pyproject.toml > package.json > environment.yml).
