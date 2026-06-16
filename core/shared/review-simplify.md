# Review + Simplify (Tool-Agnostic)

## Phase 5 — Feature Review

Review all changes since Phase 3:
```
[[SHELL:run command="git diff --stat"]]
[[SHELL:run command="git diff"]]
```

If tokensave available:
```
[CALL] tokensave_simplify_scan(files=["changed_files"])
[CALL] tokensave_dead_code
[CALL] tokensave_complexity(limit=10)
```

## Phase 6 — Simplify (MANDATORY — cannot skip)

1. **Remove dead code:**
   ```
   [CALL] tokensave_dead_code
   ```
   Fallback: `[[SHELL:run]]` grep for unused imports + `[[FILE:edit]]`

2. **Flatten abstractions:**
   - Functions wrapping single operation → inline
   - Types used in one place → move inline
   - Generics with single type → concrete

3. **Eliminate duplicates:**
   - Extract shared helpers only if 3+ occurrences

4. **Verify:**
   ```
   [[SHELL:run command="cargo test 2>&1 | tail -30"]]
   ```
