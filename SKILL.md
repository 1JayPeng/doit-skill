---
name: doit
description: "Spec-driven TDD workflow. Auto-classifies simple/feature/bug. Triggers: 我想做, 帮我加, 我需要, add feature, implement, I want to, build."
---

# Do It

Spec-driven TDD. 10 phases. Nothing ships without spec. Review + Simplify + E2E + commit mandatory.

## Skill Router

On-demand load. **[RELEASE]** after phase + `ctx_compress`。
caveman: Phase 0 [LOAD:session] 不释放 | grill-me: Phase 1 [LOAD:phase-1] 结束释放 | tdd: Phase 3 [LOAD:phase-3] 结束释放 | diagnose: Phase 0 Type B | handoff/prototype: 按需

## 铁律 + 指令 + 工具

[rules.md](rules.md)。Worklog: 每 phase 记录 (mempalace > `.doit/worklog.json`)。[worklog.md](worklog.md)
Non-Interruptive Q | Background >10s | Commit+Push | MP 读写对称 | 工作流不可跳过 | 减少暂停 | Grill 5+/3+ | 危险操作确认 | Review+Simplify
**[CALL]** = MCP。**[LOAD]** = 读文件。**[LOAD:phase-N]** = 加载 skill。**[RELEASE:phase-N]** = 释放 + ctx_compress。
4 层: codegraph + tokensave, context-mode, mempalace, headroom。RTK 自动 Bash, lean-ctx MCP 优先, headroom >500 行。CodeGraph 精准代码图查询，TokenSave 即时检测 + 高级分析（diagnostics, dead_code, complexity, test_map, 代码编辑）。
**Subagent: 默认禁用** (`subagent.enabled: false`)。配置 `true` 后 Phase 3 决策门控强制并行独立 REQ。[execute.md](execute.md)

## Phase Index

| Phase | [LOAD] | 说明 |
|-------|--------|------|
| **-1** | [env-check.md](env-check.md) | 环境检测 → CLAUDE.md + config |
| **0** | [phases.md](phases.md)#phase-0 | Sync → [LOAD:session] caveman → 分类(R/S/F/B) → MP sweep 10 并行 |
| **1** | [phases.md](phases.md)#phase-1, [learn/inject.md](learn/inject.md) | [LOAD:phase-1] grill-me → Grill(5+/3+) → Spec → Branch → Gate → [RELEASE:phase-1] grill-me → ctx_compress |
| **2** | [learn/inject.md](learn/inject.md), [plan.md](plan.md) | codegraph_context + tokensave_context → Impact → Order |
| **3** | [execute.md](execute.md) | [LOAD:phase-3] tdd → TDD per REQ → per-REQ review+simplify |
| **4** | [e2e.md](e2e.md) | E2E real env, L0+L1 auto, L2+L3 HITL |
| **5** | [review.md](review.md) | Feature review, merge duplicates |
| **6** | [shared/review-simplify.md](shared/review-simplify.md) | Duplicates, over-engineering。**不可跳过** |
| **7** | [shared/e2e-verify.md](shared/e2e-verify.md) | Re-run E2E vs spec REQs |
| **8** | [shared/commit.md](shared/commit.md) | Stage → commit → push |
| **9** | — | 清理 `.spec/current.md`, `.spec/doc-capture.md`, empty `.scratch/` |
| **9.5** | [phases.md](phases.md)#phase-9.5 | Summary → Knowledge extraction |
| **9.5.5** | [learn/extract.md](learn/extract.md) | 结构化知识 → 用户确认 → 多层存储 |
| **10** | [phases.md](phases.md)#phase-10 | Stats → MP → **`/compact`** |

**Phase Gate:** 3→4→5→6→7→8→9→9.5→9.5.5→10。**唯一合法结束 = Phase 10。**

## 辅助

文档 → `.doit/docs/` + codegraph。[doc-capture.md](doc-capture.md), [errors.md](errors.md)。Spec in git + MemPalace。Logs: `.scratch/logs/`。
**[LOAD] [phases.md](phases.md)#resume。Blank `/doit` = always resume。**
