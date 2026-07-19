# Commit + Push (Tool-Agnostic)

## Phase 8 — Commit + Push

**Step 0 — Pre-Commit Gate (MANDATORY):**

```
[[SHELL:run command="git status --short"]]
[[SHELL:run command="git diff --stat"]]
[[SHELL:run command="git log --oneline -5"]]
```

**Step 1 — Learn commit style:**
```
[[SHELL:run command="git log --oneline -10"]]
```

**Step 2 — Stage files:**
```
[[SHELL:run command="git add <specific-files>"]]
```
**Don't use `git add -A`** — may include sensitive files (.env, credentials).

**Step 3 — Draft commit message:**
按下方模板撰写**完整**提交信息，写入 `.git/COMMIT_MSG`（或临时文件）。
背景 / 已实现 / 未实现 / 结果 四段**必填**；模型训练或实验类任务必加「实验结果」段。

```
type: short description

## 背景 (Context)
<来龙去脉 + 项目背景：为什么做这件事？解决什么问题？触发来源（需求 / 缺陷 / issue）？>

## 已实现 (Implemented)
- <完成项 1，对照 REQ 或需求逐项列出>
- <完成项 2>

## 未实现 (Not Implemented / Pending)
- <已知缺口、未覆盖的 REQ、遗留风险、待办>（若无则写「无」）

## 结果 (Result)
<验证结论：构建 / 测试 / E2E 状态，关键指标或产物链接>

## 实验结果 (Experiment Results)  —— 仅模型训练 / 实验类任务
- 数据集 / 环境：
- 关键超参：
- 指标 (before → after)：
- 结论：

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

**Step 4 — Commit:**
```
[[SHELL:run command="git commit -F .git/COMMIT_MSG"]]
```

**Step 5 — Push decision:**
Read `.doit/config.yaml` — check `auto_commit.enabled`:
- `true` → push automatically
- `false` → `[[USER:ask questions=[{question:"Ready to commit and push?", header:"Commit", options:[{label:"Yes, push", description:"Push to remote"},{label:"Commit only", description:"Commit but don't push"}]]]]`

**Step 6 — Push:**
```
[[SHELL:run command="git push origin <branch>"]]
```

Read `.doit/config.yaml` — check `commit.branch`:
- `branch` → push to current branch
- `main` → push to main
