# Doit Config

Configuration via `.doit/config.yaml` in the project root. Controls workflow behavior.

## Default config.yaml

When doit first runs (Phase -1 env check), create `.doit/config.yaml` if not present:

```yaml
doc-capture:
  enabled: true
  mode: auto
  path: .doit/docs

subagent:
  enabled: true

commit:
  branch: branch
  feat_prefix: feat
  fix_prefix: fix
  refactor_prefix: refactor
```

**Values for `doc-capture.mode`:**
- `auto` — save doc silently, no confirmation
- `ask` — confirm each doc before saving
- `off` — same as `enabled: false`

**Values for `subagent.enabled`:**
- `true` — enable subagent orchestration (Conductor mode, parallel waves). Parallel execution saves 50-70% time. **Default.**
- `false` — disable subagents. All REQs executed sequentially by main agent. Token-efficient.

**Values for `commit.branch`:**
- `branch` — create `feat/...` or `fix/...` branch before push (default)
- `current` — push current branch directly, no new branch
- `none` — only commit, skip push

## When to Read

Every doit phase that modifies project state reads config first:
- Doc Capture — check `doc-capture.enabled` and `doc-capture.mode`
- Subagent — check `subagent.enabled` before launching any Agent tool calls
- Commit — check `commit.branch` and branch prefix names

## Install Interaction

During `./scripts/setup.sh`, ask user:

```
Enable doc-capture (persist reference docs in .doit/docs/)? [Y/n]
Enable subagent orchestration (parallel, faster)? [Y/n]
```

- `doc-capture`: Y → `doc-capture.enabled: true`, n → `false`
- `subagent`: y → `subagent.enabled: true`, N → `false` (default is `true`)

These defaults get written to user projects on first doit run.

After install/update, display current configuration:

```
[CONFIG] Current doit configuration:
  doc-capture.enabled: true
  subagent.enabled: true
  commit.branch: branch
```
