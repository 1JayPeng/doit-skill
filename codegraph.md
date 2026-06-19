# CodeGraph Integration

**主代码图工具** — AST 解析、符号查找、调用关系、影响分析。

---

## 定位

CodeGraph 是主要的代码图查询工具。基于 tree-sitter AST 解析，提供跨语言的精准代码图查询。

---

## 安装

```bash
# Global install
npm i -g @colbymchenry/codegraph

# Install MCP server
codegraph install --yes

# Initialize project index (first-time)
codegraph init -i
```

**验证：**
```bash
codegraph --version
claude mcp list | grep codegraph
```

---

## MCP 工具

| 工具 | 用途 |
|------|------|
| `codegraph_context` | **主要入口** — "X 如何工作"，获取综合上下文 |
| `codegraph_search` | 按名称定位符号 |
| `codegraph_callers` | 谁调用了此符号 |
| `codegraph_callees` | 此符号调用了谁 |
| `codegraph_impact` | 编辑影响面 |
| `codegraph_node` | 符号完整源码 |
| `codegraph_explore` | 多个相关符号源码一次性查看 |
| `codegraph_files` | 列出索引文件 |

---

## 工作流中的使用

### Phase 2 — 计划（代码图扫描）

1. `codegraph_context` — 理解功能如何工作，获取相关代码
2. `codegraph_search` — 定位特定符号
3. `codegraph_callers` / `codegraph_callees` — 调用链
4. `codegraph_impact` — 评估编辑影响面
5. `codegraph_node` — 获取符号完整源码

### 关键原则

- **Trust the results** — 不要使用 grep 重新验证。索引是预构建的。
- **将返回的源码视为已读取** — 无需重新读取文件。
- **Auto-sync** — 文件监听器 ~500ms 延迟；编辑后不要立即重新查询。
- **直接回答** — `codegraph_context` 优先，然后 ONE `codegraph_explore` 查看源码。不要 grep+read 循环。
- **如果 `.codegraph/` 不存在**，提供运行 `codegraph init -i`。

---

## 集成点

| 文件 | 变更 |
|------|------|
| `package.json` | 添加到 `tools` 部分 |
| `scripts/setup.sh` | Step 3.8: 安装 + 初始化 |
| `env-check.md` | 工具可用性检查 |
| `tool-integration-guide.md` | 工具概览 + Phase 使用 |
| `.gitignore` | `.codegraph/` |

---

## CodeGraph 不是什么

- **不是编辑器** — 只读代码图查询。使用原生 Edit/Write 修改文件。
- **不是记忆系统** — 仅代码结构，无语义记忆。使用 MemPalace。
