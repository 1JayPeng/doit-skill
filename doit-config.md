# Doit Config

Configuration via `.doit/config.yaml` in the project root. Controls workflow behavior.

## Default config.yaml

When doit first runs (Phase -1 env check), create `.doit/config.yaml` if not present:

```yaml
doc-capture:
  enabled: true
  mode: auto
  path: .doit/docs

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

**Values for `commit.branch`:**
- `branch` — create `feat/...` or `fix/...` branch before push (default)
- `current` — push current branch directly, no new branch
- `none` — only commit, skip push

## When to Read

Every doit phase that modifies project state reads config first:
- Doc Capture — check `doc-capture.enabled` and `doc-capture.mode`
- Commit — check `commit.branch` and branch prefix names

## Install Interaction

During `./scripts/install.sh`, ask user:
```
Enable doc-capture (persist reference docs in .doit/docs/)? [Y/n]
```

- Y → default config ships with `doc-capture.enabled: true`
- n → default config ships with `doc-capture.enabled: false`

This default gets written to user projects on first doit run.
