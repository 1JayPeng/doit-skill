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

**Step 1: [LOAD:phase-1] grill-me → Grill FIRST (before writing any REQs):**
- `[[SKILL:route target="grill-me"]]` — load grill protocol
- **Uncertainty scan:** List 3-5 things you're uncertain about. Rate 1-5. Focus questions on items >= 3.
- Ask 4+ questions via `[[USER:ask]]` (Type F) or 3+ (Type B). Each question must:
  - Reference a specific detail from the user's request
  - Explain WHY the answer matters
  - Provide 2-4 concrete options with: **named approach** + **`->` consequence** + **`Trade-off:`** + **`适合:` project fit**
  - Exactly one option marked `(Recommended)`
- E2E feasibility check — `[[USER:ask]]`: "Which of the following does this feature rely on for E2E testing?" (check ALL that apply):
  - `Network service` (API endpoint that must be reachable)
  - `Database` (PostgreSQL/Redis/MySQL that must be running)
  - `Browser` (Playwright/headless Chromium for web E2E)
  - `Docker` (containerized service for integration tests)
  - `Filesystem` (specific paths or mounts required)
  - `None` (CLI-only, no external dependencies)
- **If any dependency is checked**, announce in grill summary: `[E2E DEPENDENCY: <name>] <host:port / driver>`
- **Cross-reference with Phase -1 probe results:** If Phase -1 probe `[FAIL]`ed a service that the user selected here, explicitly flag it in the grill summary as `[CRITICAL E2E BLOCKER]` and ask: "Should we mark this REQ as HITL-only, or wait until the service is available?"
- This question MUST be asked even if Phase -1 probes succeeded — Phase -1 probes the *machine*, Phase 1 confirms *this feature's* actual dependencies. Different services may be needed than what Phase -1 found.
- Internet search — Tavily MCP (primary), Firecrawl MCP/CLI (when Tavily unavailable), `[[WEB:search]]` (fallback)
- **External docs:** `[CALL] ctx_url_read(url, mode="markdown")` — fetch web pages/PDFs
- MP search for prior specs — `mempalace_search wing="<project>"`
- Write grill summary to `.doit/grill-summary.json`
- **Do NOT write any REQs until grill is complete.**
**Step 1.5: YAGNI Check (before spec) — /ponytail:**

If ponytail plugin available, run `/ponytail` to activate the decision ladder before writing spec. Forces spec design to prefer minimal viable solutions — native features, stdlib, standard patterns before custom code. This prevents over-engineering from the spec stage, not after.

```
/ponytail
```

**Step 2: Write spec** — Split grill output into REQ-N items, save to `.spec/current.md`. See [../spec.md](../spec.md).

**铁律：Grill 最低 4 个问题(Type F) / 3 个(Type B)。** Phase 1 必须至少 4 个 grill 问题（通过 `[[USER:ask]]`）。少于 4 个 = 未完成的 Phase 1 = 不能进入 Phase 2。

**Phase 1 完成后：** 记录工作日志。See [../worklog.md](../worklog.md)。

**[RELEASE:phase-1] grill-me** — grill protocol complete, release grill-me skill. Execute `[[MEMORY:compress]]`.

### Phase 1 → Phase 2 Gate

进入 Phase 2 前，自检：
1. 统计本会话 `[[USER:ask]]` 调用次数 — 必须 >= 4 (Type F) 或 >= 3 (Type B)
2. 确认 GRILL CHECKLIST 全部完成
3. 确认 `.doit/grill-summary.json` 已写入
4. 如果任一检查失败，返回 Phase 1 补全
