# Spec: 渐进式披露 — Skill 加载升级

**日期:** 2026-06-09
**类型:** Type F (feature)
**目标:** 将 skill 加载从 Phase 0 一次性全量加载升级为渐进式披露模式

## 决策记录 (Grill 12 问)

| # | 问题 | 决策 |
|---|------|------|
| Q1 | 作用范围 | 全套：skill + 安装脚本 + 文档 |
| Q2 | 释放机制 | 上下文提示 + /compact |
| Q3 | 加载粒度 | 按 Phase 粒度 |
| Q4 | 向后兼容 | 自然升级（不兼容） |
| Q5 | SKILL.md 压缩 | 压缩至 ~50 行路由表 |
| Q6 | 指令语法 | [LOAD:phase-N] + [RELEASE:skill] |
| Q7 | 子 skill 发现 | 分类驱动加载 |
| Q8 | CLAUDE.md 生成 | 重写 Skill Loading 段为渐进式 |
| Q9 | caveman 处理 | 全程驻留，不参与释放 |
| Q10 | 实施顺序 | 先写 spec，再改文件 |
| Q11 | 验证策略 | Token 对比 + 手动验证 |
| Q12 | 文件范围 | 核心 3 文件 (SKILL.md, phases.md, env-check.md) |

## 需求

### REQ-001: SKILL.md 压缩至路由表

**目标:** SKILL.md 从 297 行压缩至 ~50 行

**变更内容:**
- 保留: frontmatter (name/description), Phase 索引 + [LOAD] 指令, 铁律摘要表
- 移除: Memory Layer 详情 -> plan.md/agentmemory.md/mempalace.md, Principles 详情 -> principles.md, 铁律详情 -> rules.md, Subagent 详情 -> subagent.md, 工作流详情 -> worklog.md, Phase 描述 -> phases.md, Token 优化工具详情 -> 各自文档
- 新增: Skill 路由表 (见 REQ-003)

**验证:** `wc -l SKILL.md` <= 60 行

### REQ-002: [LOAD:phase-N] + [RELEASE:skill] 指令集

**目标:** 扩展 [LOAD] 指令，支持 skill 生命周期管理

**新指令格式:**
```
[LOAD:phase-N] skill-name — 加载原因
[RELEASE:phase-N] skill-name — 释放说明
```

**示例:**
```
Phase 1 — Spec:
  [LOAD:phase-1] grill-me — grill 协议指令
  ... (Phase 1 执行) ...
  [RELEASE:phase-1] grill-me — grill 完成，上下文释放
```

**caveman 特例:**
```
[LOAD:session] caveman — 行为修改型，全程驻留
```
caveman 不参与 [RELEASE]，每轮响应都需生效。

**phases.md 变更:**
- Phase 0 Step 1 改为只加载 doit + caveman
- grill-me 改为 [LOAD:phase-1] 在 Phase 1 开始时加载
- 每个 phase 结束添加 [RELEASE:phase-N] 释放该 phase 加载的 skill
- 新增 Phase 指令定义段落，解释 [LOAD:phase-N] 和 [RELEASE:skill] 语义

### REQ-003: Skill 路由表

**目标:** SKILL.md 新增 Skill 路由表，分类驱动加载

**路由表格式:**
```markdown
## Skill Router

| Skill | Type | Load When | Release When |
|-------|------|-----------|-------------|
| caveman | behavior | Phase 0, [LOAD:session] | 不释放 |
| grill-me | feature | Phase 1, [LOAD:phase-1] | Phase 1 结束 |
| tdd | feature | Phase 3, Type F/B | Phase 3 结束 |
| diagnose | feature | Phase 0, Type B | Debug 结束 |
| handoff | feature | 用户要求时 | 完成 |
| prototype | feature | 用户要求时 | 完成 |
```

**Type 说明:**
- `behavior` — 行为修改型，全程驻留
- `feature` — 功能型，按需加载/释放

### REQ-004: 分类驱动 Skill 加载

**目标:** 根据请求类型自动加载对应 skill

**加载逻辑:**
```
Phase 0 分类结果 -> Skill 加载策略:
  Type R (resume) -> 无额外 skill
  Type S (simple) -> 无额外 skill
  Type F (feature) -> Phase 1 加载 grill-me, Phase 3 加载 tdd
  Type B (bug) -> Phase 0 加载 diagnose
```

**实现位置:** phases.md Phase 0 Step 1 逻辑更新

### REQ-005: env-check.md CLAUDE.md 模板升级

**目标:** Phase -1 写入用户项目 CLAUDE.md 的 Skill Loading 段改为渐进式

**变更前 (env-check.md Step 10):**
```markdown
## Skill Loading
Skills to load on every session:
- doit — always active
- caveman — terse mode
```

**变更后:**
```markdown
## Skill Loading — Progressive Disclosure

Skills load on-demand by phase. See SKILL.md Skill Router for full lifecycle.

Phase -1: load doit
Phase 0: load caveman (stays loaded)
Phase 1: load grill-me -> release after Phase 1
Phase 3: load tdd -> release after Phase 3
Type B: load diagnose -> release after debug
```

**实现位置:** env-check.md Step 10 模板更新

### REQ-006: [RELEASE] + ctx_compress 双重保障

**目标:** 确保 skill 释放后上下文实际缩小

**机制:**
1. [RELEASE:phase-N] skill-name — 声明式释放，模型忽略该 skill 指令
2. 紧跟 `ctx_compress` 调用 — 物理压缩上下文窗口

**实现位置:** phases.md 每个 phase 结束处添加 [RELEASE] + ctx_compress 指令

## 不变项

- [LOAD] 文件读取指令保持不变（与 [LOAD:phase-N] skill 加载指令共存，通过上下文区分）
- Phase 工作流顺序不变
- 铁律内容不变
- 子文件 (plan.md, execute.md, etc.) 内容不变
- setup.sh 安装逻辑不变（cp 覆盖即升级）

## 验收标准

- [ ] SKILL.md <= 60 行
- [ ] phases.md 包含 [LOAD:phase-N] 和 [RELEASE:phase-N] 指令定义
- [ ] phases.md Phase 0 只加载 doit + caveman，不加载 grill-me
- [ ] env-check.md Step 10 CLAUDE.md 模板为渐进式
- [ ] Skill 路由表在 SKILL.md 中
- [ ] `./scripts/setup.sh --dry-run` 通过
- [ ] `./scripts/setup.sh` 安装成功
- [ ] 安装后 `.claude/skills/doit/SKILL.md` 为新版本
