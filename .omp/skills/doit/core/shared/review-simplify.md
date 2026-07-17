# Review + Simplify (Tool-Agnostic)

## Phase 5 — Feature Review

Review all changes since Phase 3:
```
[[SHELL:run command="git diff --stat"]]
[[SHELL:run command="git diff"]]
```

## Phase 6 — Simplify (MANDATORY — cannot skip)

0. **Ponytail review (optional, fallback only):** If ponytail plugin available, run `/ponytail-review` as a final check. The main YAGNI prevention happens in Phase 1-3 via `/ponytail` (decision ladder activated before spec/plan/implementation). This step catches over-engineering missed earlier.

1. **Remove dead code:**
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
