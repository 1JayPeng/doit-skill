# Spec: Grill Optimization — 让模型真正提问而非猜测

**Date:** 2026-06-06
**Type:** Feature
**Goal:** 解决 grill 机制在实际中被跳过的问题。模型倾向于猜测/假设而非向用户提问。通过 3 个子代理并行分析，定位 8 个根本原因，逐一修复。

## Context

### 问题现象
- 用户说"帮我加个功能"，模型直接写 REQ，不问任何问题
- 或者问 1-2 个泛泛的问题，然后自己假设答案
- 导致 spec 质量差，实现方向错误

### 根本原因（3 个子代理分析结果）

**Agent 1 — 根本原因:**
1. grill-me skill 从未被 `Skill` 工具加载（SKILL.md 只加载 doit + caveman）
2. "用默认值继续"规则给了模型跳过提问的借口
3. 没有过程执行机制（无计数器、无 gate 检查）
4. Grill 指令在 SKILL.md 中只有 3 行（Phase 1 共 3 行 vs Phase 0 72 行）
5. "永不阻塞"铁律与 grill 交互需求冲突
6. grill-me 自相矛盾（12 题 vs Smart Mode 允许跳过）
7. AskUserQuestion 不是 gate 机制
8. Phase 1 段落塞了 5 个任务

**Agent 2 — Prompt 问题:**
1. 分类标签（"edge cases"）而非具体问题模板
2. LLM 是"回答引擎"而非"提问引擎"，天生倾向给答案
3. 没有不确定性检测步骤
4. 12 题太多，质量递减
5. 没有好/坏问题对比示例
6. spec.md 说 3 题，grill-me 说 12 题，数量冲突

**Agent 3 — 执行缺口:**
1. Phase Gate Checklist 没有 grill 子检查
2. "默认值"条款 = 跳过悖论
3. Phase 1 → Phase 2 没有验证 gate
4. grill-me Smart Mode 允许完全跳过
5. Grill checklist 不可验证（无输出产物）
6. errors.md 不覆盖 grill 被跳过的情况

## Requirements

### REQ-001: 加载 grill-me skill

**文件:** `SKILL.md` Phase 0 Step 1

在 Phase 0 的 skill 加载步骤中，增加 `grill-me` skill 加载：

```
Skill skill="doit"
Skill skill="caveman"
Skill skill="grill-me"
```

如果 grill-me 不存在，输出 `[WARN] grill-me not installed -> basic grill mode` 并继续。

**Why:** grill-me skill 定义了完整的 grill 协议，但从未被加载。模型只看到文本引用，没有激活的 prompt 指令。

---

### REQ-002: 修复"默认值"跳过悖论

**文件:** `SKILL.md` 铁律 Non-Interruptive Questions, `spec.md` Step 2, `principles.md` Principle 0

在所有 3 个文件中，给"用默认值继续"规则增加 grill 例外：

```
- 用户不回答 -> 用默认值继续
- **例外：grill 问题不适用此规则。** grill 问题必须先被提出，然后用户不回答才用默认值。跳过 grill 问题 ≠ 用户不回答。
```

**Why:** 模型利用"用户不回答 -> 用默认值"的逻辑漏洞：既然用户没回答（因为根本没问），那就用默认值继续。增加例外关闭此漏洞。

---

### REQ-003: 增加 Phase 1 → Phase 2 验证 Gate

**文件:** `SKILL.md` Phase 1 和 Phase 2 之间

在 Phase 1 和 Phase 2 之间新增 gate 段落：

```
## Phase 1 → Phase 2 Gate

进入 Phase 2 前，自检：
1. 统计本会话 AskUserQuestion 调用次数 — 必须 >= 3 个 grill 问题
2. 确认 GRILL CHECKLIST 全部完成（challenge, search, MP, alternatives, scope）
3. 如果任一检查失败，返回 Phase 1 补全缺失步骤

未通过自检 = Phase 1 未完成 = 不能进入 Phase 2。
```

**Why:** 目前 Phase 1 和 Phase 2 之间没有任何 gate。铁律说"少于 3 个 = 不能进入 Phase 2"但没有操作步骤。

---

### REQ-004: 扩展 Phase 1 描述

**文件:** `SKILL.md` Phase 1 段落

将 Phase 1 从 3 行扩展到包含 grill 关键步骤的内联描述：

```
## Phase 1 — Spec

Write spec. See [spec.md](spec.md).

**Step 1: Grill FIRST (before anything else):**
- Load grill-me skill: `Skill skill="grill-me"`
- Ask 3+ questions via AskUserQuestion (challenge assumptions, alternatives, scope)
- Internet search for existing solutions (Tavily MCP or WebSearch)
- MP search for prior specs/knowledge
- **Do NOT write any REQs until grill is complete.**

**Step 2: Write spec** — Split grill output into REQ-N items, save to `.spec/current.md`

**铁律：Grill 最低 3 个问题。** Phase 1 必须至少 3 个 grill 问题（通过 AskUserQuestion）。少于 3 个 = 未完成的 Phase 1 = 不能进入 Phase 2。
```

**Why:** Phase 1 原来只有 3 行，grill 指令被淹没在搜索、REQ、保存等 5 个任务中。

---

### REQ-005: 统一 grill 问题数量

**文件:** `skills/grill-me/SKILL.md`, `spec.md`, `principles.md`

统一问题数量标准：
- Type F (feature): 5 题 minimum
- Type B (bug): 3 题 minimum
- Type S (simple): 可跳过 grill

删除 grill-me 中的 "12 questions minimum, always" 和 "3 rounds × 4 questions"。改为不确定性驱动的问题数量。

删除 grill-me 的 "Smart Mode" 中 "skip grill entirely" 选项。改为 "Type S 可跳过，Type F/B 不可跳过"。

**Why:** spec.md 说 3 题，grill-me 说 12 题，模型看到冲突信号就选最少的。统一标准消除冲突。

---

### REQ-006: 增加不确定性检测步骤

**文件:** `skills/grill-me/SKILL.md`

在 grill 问题生成前，增加不确定性扫描步骤：

```
## Step 0: Uncertainty Scan (内部步骤，不展示给用户)

在生成问题前，列出用户请求中你不确定的 3-5 个具体点。每个评分 1-5（5=完全不清楚）。只针对评分 >= 3 的点生成问题。

示例：
- "用户说'加搜索' — 不确定是全文搜索、模糊匹配还是精确匹配" [5]
- "用户说'高性能' — 不确定是 <100ms 还是 <1s" [4]
- "用户说'存数据' — 不确定 SQLite/PostgreSQL/文件" [3]
- "用户要 REST API — 标准模式，低不确定性" [1] -> 跳过
```

**Why:** 模型不知道什么该问。不确定性扫描强制模型识别知识缺口，然后针对缺口提问。

---

### REQ-007: 增加问题模板 + 反模式

**文件:** `skills/grill-me/SKILL.md`

用具体问题模板替换分类标签（"edge cases", "failure modes"）：

```
## 问题模板（根据上下文适配）

不要问："有什么边界情况？"
要问："当[用户请求中的具体场景]中途失败，[具体数据/状态]应该怎样？用户没有指定回滚行为。"

不要问："范围是什么？"
要问："请求提到[功能X]和[功能Y]。这两个通常是独立模块。本次交付包含两者还是选一个？"

## 反模式 — 这些不是 grill 问题

永远不要问：
- "需求是什么？" -> 你应该已经从请求中知道了
- "用什么技术？" -> 先检查代码库
- "这个方案对吗？" -> 太模糊，要具体
- "还有其他顾虑吗？" -> 兜底问题，不是真问题

每个问题必须包含：
1. 引用用户请求中的具体细节
2. 解释为什么答案重要（答错的后果）
3. 至少 2 个具体选项供用户选择
```

**Why:** 分类标签让模型生成泛泛的问题。模板 + 反模式让模型生成具体问题。

---

### REQ-008: 增加 grill 输出产物

**文件:** `spec.md` Step 2

在 grill checklist 完成后，要求写入 `.doit/grill-summary.json`：

```json
{
  "questions_asked": 5,
  "checklist": {
    "challenge_assumptions": true,
    "internet_search": true,
    "mp_search": true,
    "alternative_approaches": true,
    "scope_clarification": true
  },
  "questions": ["Q1", "Q2", "Q3", "Q4", "Q5"],
  "answers": {"Q1": "...", "Q2": "..."}
}
```

**Why:** Checklist 只在文档中存在，模型可以"心理打勾"。写入文件 = 可验证产物。

---

### REQ-009: 增加 grill 跳过错误处理

**文件:** `errors.md`

新增错误处理：

```
### Phase 1 (Spec) — Grill Skipped

Phase 1 完成或 Phase 2 已开始，但没有 3+ 个 grill 问题通过 AskUserQuestion。

**Action:** 停止。返回 Phase 1 Step 2。完成完整 grill checklist。不要丢弃已写的 REQ — 用 grill 结果补充它们，然后合并到现有 REQ 中。
```

**Why:** errors.md 覆盖了 grill 发现想法不可行的情况，但不覆盖 grill 被完全跳过的情况。

---

### REQ-010: 更新 Phase Gate Checklist

**文件:** `SKILL.md` Phase Gate Checklist

将 Phase 1 检查项分解为子检查：

```
[x] Phase 1     Spec
  [x] grill-me skill loaded
  [x] 3+ grill questions via AskUserQuestion
  [x] GRILL CHECKLIST completed (challenge, search, MP, alternatives, scope)
  [x] .doit/grill-summary.json written
  [x] .spec/current.md written
  [x] Branch created
```

**Why:** 原来的 `[x] Phase 1 Spec (grill → write → branch)` 没有可验证的子项。

---

## E2E Scenario

1. 用户说 `/doit 帮我加个用户登录功能`
2. Agent 分类 Type F
3. Agent 加载 doit + caveman + **grill-me** skill（REQ-001）
4. Agent 做不确定性扫描（REQ-006）
5. Agent 用 AskUserQuestion 问 >= 3 个具体问题（REQ-007 模板）
6. 用户回答问题（或不回答 -> 用默认值，但问题已经被问了 REQ-002）
7. Agent 写 `.doit/grill-summary.json`（REQ-008）
8. Agent 自检 Phase 1 → Phase 2 gate（REQ-003）
9. Agent 写 spec、创建分支
10. Phase Gate Checklist 显示 grill 子检查通过（REQ-010）

## Out of Scope

- 自动检测模型是否跳过了 grill（需要外部监控）
- grill 问题的 ML 评分系统
- 跨会话 grill 历史对比
