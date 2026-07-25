# Review + Simplify (Tool-Agnostic)

## Phase 5 — Feature Review

Review all changes since Phase 3:
```
[[SHELL:run command="git diff --stat"]]
[[SHELL:run command="git diff"]]
```

## Phase 6 — Simplify (MANDATORY — cannot skip)

0. **Ponytail reuse check (MANDATORY first):** Run `/ponytail` (and `/ponytail-review` if available). Before editing, check in order: existing codebase reuse → standard library/标准库 → native platform → installed dependency → GitHub/reference implementation. If GitHub code can be borrowed/copied, prefer the smallest license-compatible copy or direct reuse, cite the source, and avoid new custom code. Only write custom code after these fail.

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
