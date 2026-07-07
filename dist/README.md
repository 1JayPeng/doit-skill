# Distribution

This directory contains tools for building the distributable package of doit-skill.

## Dev vs Distribution

| Aspect | Dev (root repo) | Distribution |
|--------|----------------|--------------|
| `.doit/config.yaml` | `subagent: true` | NOT included — setup.sh writes `~/.doit/config.yaml` with `subagent: false` |
| `.codegraph/` | Local index | Excluded |
| `.env` | Local API keys | Excluded |
| `data/` | Local data | Excluded |

## Build

```bash
./dist/build.sh  # Creates dist/output/doit-skill-dist.tar.gz
```

The tarball excludes all dev-only files. Setup.sh installs from the GitHub repo directly and applies the same exclusion logic via rsync.

## Git

- `dist/build.sh` — tracked in git
- `dist/output/` — gitignored (generated on demand)
- `dist/*.tar.gz` — gitignored (generated on demand)
- `.doit/` — gitignored (dev-only config)
