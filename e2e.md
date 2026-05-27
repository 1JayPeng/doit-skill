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

## Tool Calling

### Run E2E Tests

**Primary:** Use Context-Mode to auto-index test output:
```
ctx_execute(language="shell", code="uv run pytest tests/e2e/ -v --tb=short")
ctx_execute(language="shell", code="uv run python -m pytest tests/e2e/ -v --tb=short")
```
- **Fallback:** If Context-Mode unavailable -> native Bash tool (output not indexed).

### Detect Test Framework (before generating tests)

Scan project config to determine the test runner:
```
ctx_batch_execute(
  commands=[
    {"label": "pyproject.toml", "command": "cat pyproject.toml 2>/dev/null || echo missing"},
    {"label": "package.json scripts", "command": "cat package.json 2>/dev/null | grep -A5 scripts || echo missing"},
    {"label": "test dirs", "command": "find . -maxdepth 3 -type d -name test\* -o -name __tests__ 2>/dev/null | head -10"},
  ],
  queries=["pytest", "jest", "test runner", "test framework"]
)
```
- **Fallback:** If Context-Mode unavailable -> parallel Bash calls to `cat` + `find`.

**tokensave** tools for understanding entry points:
1. `tokensave_search(query="<entry_point_name>")` — find the entry point function
2. `tokensave_node(node_id="<id>")` — get function signature for test generation
3. `tokensave_test_map(file="<source_file>")` — check existing test coverage
- **Fallback:** If TokenSave unavailable -> `grep -rn "def " src/` + `Read` the file.

### Spec Alignment Check Tools

After tests pass, compare output against spec:
1. `ctx_search(queries=[<REQ descriptions>])` — look up spec REQs from indexed content
   - **Fallback:** Read `.spec/current.md` directly.
2. `tokensave_diff_context(files=[<changed_files>])` — which symbols changed, semantic impact
   - **Fallback:** `git diff --name-only` + `git diff <file>`.

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

### Spec Alignment Check (per REQ)

**E2E tests are not just about code running — they verify output matches what the user asked for.**

For each REQ in `.spec/current.md`:

1. Read REQ description and expected behavior
2. Find the e2e test that covers this REQ
3. Run the test, capture actual output
4. **Compare actual output against spec expectation — not the test assertion**

```
REQ-001: "user can login and see dashboard"
  Expected: dashboard page with user greeting
  Actual:   "Welcome back, test" on /dashboard URL
  Match?    Yes

REQ-002: "unauthorized access returns 403"
  Expected: 403 error, no page content
  Actual:   401 error, login redirect
  Match?    No — wrong status code and behavior differs from spec
```

**Key: compare output against spec, not against test assertion.** The test assertion might have been changed to match wrong output (AI lying to itself). Always read the spec as the ground truth.

## Phase 5 Pre-flight Gate

Phase 5 must not start until Phase 4 produces `e2e: passed`. Verify: all L0+L1 e2e tests passed.

## E2E Verification Loop (Phase 7 / D5)

**Canonical source: [shared/e2e-verify.md](shared/e2e-verify.md)**

Both feature flow (Phase 7) and debug flow (D5) use the same E2E Verification Loop.
The shared file is the single source of truth — update rules there, not here.
