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

### 5. Cannot Determine Environment

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

### 6. Announce Detected Environment

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
