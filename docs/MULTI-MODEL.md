# Multi-Model Configuration for OMP

doit-skill supports OMP's multi-model architecture for optimized workflow execution.

## Model Roles

OMP provides three model tiers for different task complexities:

| Model | Role | Use Case |
|-------|------|----------|
| **smol** | Fast/lightweight | Phase 0 classification, quick queries |
| **slow** | Reasoning/thinking | Phase 1 spec, Phase 3 execution, review |
| **plan** | Architecture/planning | Phase 2 planning, impact analysis |

## Configuration

### Via setup.sh

```bash
# During interactive setup
./scripts/setup.sh

# Or with explicit model parameters
./scripts/setup.sh --smol qwen3-0.6b --slow claude-sonnet-4-20250514 --plan claude-opus-4-20250514
```

### Via multi-model.sh

```bash
# Set individual models
./scripts/multi-model.sh --smol qwen3-0.6b
./scripts/multi-model.sh --slow claude-sonnet-4-20250514
./scripts/multi-model.sh --plan claude-opus-4-20250514

# Check current configuration
./scripts/multi-model.sh --check
```

### Manual Configuration

Edit `~/.doit/config.yaml`:

```yaml
models:
  smol: "qwen3-0.6b"
  slow: "claude-sonnet-4-20250514"
  plan: "claude-opus-4-20250514"
```

## Workflow Integration

doit-skill uses different models for different phases:

- **Phase 0 (Classify)**: Uses `smol` model for fast request classification
- **Phase 1 (Spec)**: Uses `slow` model for requirement analysis and spec writing
- **Phase 2 (Plan)**: Uses `plan` model for architecture planning and impact analysis
- **Phase 3 (Execute)**: Uses `slow` model for TDD execution and code generation
- **Phase 4-9**: Uses appropriate models based on task complexity

## Benefits

1. **Cost Optimization**: Use cheaper models for simple tasks
2. **Speed**: Fast classification and quick queries with smol
3. **Quality**: Deep reasoning for complex tasks with slow/plan
4. **Flexibility**: Configure models per agent or globally

## Example Setup

```bash
# Budget-conscious setup
./scripts/setup.sh \
  --smol qwen3-0.6b \
  --slow qwen3-27b \
  --plan claude-opus-4-20250514

# Quality-focused setup
./scripts/setup.sh \
  --smol claude-haiku-3.5 \
  --slow claude-sonnet-4-20250514 \
  --plan claude-opus-4-20250514

# Local-only setup (no API costs)
./scripts/setup.sh \
  --smol qwen3-0.6b \
  --slow qwen3-27b \
  --plan qwen3-27b
```

## Notes

- Models are optional. If not configured, OMP uses its default model settings.
- Model names follow OMP's fuzzy matching (e.g., "opus", "sonnet", "qwen3-27b").
- Configuration is stored in `~/.doit/config.yaml` under the `models:` section.