# Phase 1 — Spec (Tool-Agnostic)

**Step 0 — Read Config (MANDATORY):**

Read `.doit/config.yaml` and announce effective settings:
```
[CONFIG] subagent.enabled: true/false
[CONFIG] auto_commit.enabled: true/false
```

**Step 0.5 — Knowledge Injection (before grill):**

**[LOAD] [../learn/inject.md](../learn/inject.md) — search, rank, inject.**

1. Search for relevant past sessions using user's request as semantic query
2. Rank by relevance + time decay
3. Inject top-3 into context as `[LEARN] Related past sessions:`
4. Use injected knowledge to pre-fill grill options and warn about known pitfalls

**Step 0.75: MemPalace Knowledge Pre-fill (before grill, if available):**

Before running grill, search MemPalace for relevant past knowledge about this project:

```
mempalace_search wing="<project>" query="<user request keywords>" max_distance=0.6
mempalace_kg_query entity="<project>"
```

If results found, synthesize them as `[LEARN] MemPalace prior knowledge:` and use to:
1. **Pre-fill grill options** — if past sessions made design decisions (e.g., "used JWT auth"), include those as grill options so the user can confirm or override instead of re-explaining
2. **Warn about known pitfalls** — if past sessions recorded gotchas/errors, surface them before grill questions
3. **Reduce redundant grill questions** — if the answer is already known from KG, skip that question and just confirm: "Last time we used X. Still correct?"

This step complements Step 0.5 (Knowledge Injection) which uses lean-ctx's semantic search. MemPalace provides structured KG facts that lean-ctx doesn't index.

**If MemPalace unavailable or no results:** Skip silently. Grill proceeds without pre-fill.
- `[[SKILL:route target="deep-grill"]]` — load deep-grill (EN) or `[[SKILL:route target="deep-grill-cn"]]` (CN)
- **Mode A (Socratic):** Attack claims from every angle — evidence, perspective, implications, counterfactuals
- **Mode B (First Principles):** Reduce to fundamentals when assumptions surface. Don't announce mode switches — just ask the question.
- **FP Injection Triggers (MANDATORY switch to Mode B):**
  + Trigger #1: Rebuilding with old-framework parts → "What do we know to be absolutely true about X?"
  + Trigger #2: Circular reasoning → "How do we know this premise is true?"
  + Trigger #3: Authority-based claim → "What's the evidence independent of authority?"
  + Trigger #4: Unexamined definition → "How would we define X without referencing Y?"
  + Trigger #5: Complexity accepted as necessary → "Is this complexity truly required, or assumed?"
  + Trigger #6: Emotional/ego attachment → "If you were wrong about X, what would change?"
- **4 Movements (direction, not sequence):**
  + **Deconstruct:** Surface and dismantle core assumptions (Mode B heavy)
  + **Cross-examine:** Attack surviving assumptions (Mode A heavy)
  + **Rebuild:** Only from verified truths — simplest solution (Occam's Razor)
  + **Meta:** Are we asking the right question? Blind spots? What overturns the conclusion?
- Ask 4+ questions via `[[USER:ask]]` (Type F) or 3+ (Type B). Each question must:
  + Reference a specific detail from the user's request
  + Explain WHY the answer matters
  + Provide 2-4 concrete options with: **named approach** + **`->` consequence** + **`Trade-off:`** + **`适合:` project fit**
  + Exactly one option marked `(Recommended)`
- **Watch for Mental Traps** — call them out: Confirmation bias, Anchoring, Scope creep, Analysis paralysis, Survivorship bias, Authority bias, Sunk cost
- E2E feasibility check — `[[USER:ask]]`: "Which of the following does this feature rely on for E2E testing?" (check ALL that apply):
  + `Network service` (API endpoint that must be reachable)
  + `Database` (PostgreSQL/Redis/MySQL that must be running)
  + `Browser` (Playwright/headless Chromium for web E2E)
  + `Docker` (containerized service for integration tests)
  + `Filesystem` (specific paths or mounts required)
  + `None` (CLI-only, no external dependencies)
- **If any dependency is checked**, announce in grill summary: `[E2E DEPENDENCY: <name>] <host:port / driver>`
- **Cross-reference with Phase -1 probe results:** If Phase -1 probe `[FAIL]`ed a service that the user selected here, explicitly flag it in the grill summary as `[CRITICAL E2E BLOCKER]` and ask: "Should we mark this REQ as HITL-only, or wait until the service is available?"
- This question MUST be asked even if Phase -1 probes succeeded — Phase -1 probes the *machine*, Phase 1 confirms *this feature's* actual dependencies. Different services may be needed than what Phase -1 found.
- Internet search — Tavily MCP (primary), Firecrawl MCP/CLI (when Tavily unavailable), `[[WEB:search]]` (fallback)
- **External docs:** `[CALL] ctx_url_read(url, mode="markdown")` — fetch web pages/PDFs
- MP search for prior specs — `mempalace_search wing="<project>"`
- Write grill summary to `.doit/grill-summary.json` (including assumptions challenged, rebuilt truths, meta-insights)
- **Do NOT write any REQs until interrogation is complete.**

**For Type B (bug) / Type S (simple) tasks:** fall back to `grill-me` for abbreviated Q&A:
- `[[SKILL:route target="grill-me"]]` — 3 questions (Type B), skip grill for trivial Type S

### Phase 1 → Phase 2 Gate

进入 Phase 2 前，自检：
1. 统计本会话 `[[USER:ask]]` 调用次数 — 必须 >= 4 (Type F) 或 >= 3 (Type B)
2. 确认 GRILL CHECKLIST 全部完成
3. 确认 `.doit/grill-summary.json` 已写入
4. 如果任一检查失败，返回 Phase 1 补全
