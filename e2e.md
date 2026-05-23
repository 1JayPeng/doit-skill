# Phase 4: End-to-End Testing

## Rules

- E2E tests run in real project environment (uv venv)
- Every entry point tested. Every entry parameter tested.
- If automation is hard -> HITL (hand it to user)

## What E2E is NOT

Phase 3 unit tests cover: internal functions, mocked dependencies, isolated paths.
Phase 4 E2E tests cover: real entry points, real I/O, integration of all layers.

**E2E ≠ "unit tests but with subprocess."** You're testing the user's full journey, not function signatures.

**Common anti-pattern:** Replacing `import main` with `subprocess.run` but still asserting internal state. Instead assert: exit code, stdout/stderr, file output, database state — things the user observes.

## Test Level Taxonomy

| Level | What | Auto? |
|-------|------|-------|
| L0 | Required params, happy path | Yes |
| L1 | Boundary values (empty, max, min, special chars) | Yes |
| L2 | Conflicting param combinations | HITL |
| L3 | Fuzzy/random input, stability | HITL |

## L0/L1 Auto-Generate

For each entry point (function, CLI command, API):

1. List all parameters from signature
2. Generate L0: one valid call per entry point
3. Generate L1: boundary for each param

```python
# Auto-generated e2e skeleton
import subprocess, sys

def run_entry(name, args):
    result = subprocess.run([sys.executable, "-m", "main"] + args, capture_output=True, text=True)
    return result

# L0: happy path
run_entry("login", ["--user", "test", "--pass", "abc123"])

# L1: boundary
run_entry("login", ["--user", "", "--pass", "abc123"])  # empty user
```

## L2/L3 HITL

Present untested combinations to user:
```
L2 HITL: These param combos need manual testing:
  1. --flag-a + --flag-b (conflict expected?)
  2. --mode=debug + --verbose (redundant?)

Run each, paste output. I'll generate assertion.
```

## E2E + Spec Cross-Check

Compare e2e coverage against spec acceptance criteria. Missing -> flag to user.

## State Persistence

After Phase 4 completes (all L0+L1 tests run):
Write to `.scratch/workflow-state.json`:
```json
{ "phase": "e2e", "e2e": "passed", "l0_entry_points": N, "l1_boundary_values": M }
```
If tests failed: `"e2e": "failed"`. This is what Phase 5 pre-flight gate checks.
