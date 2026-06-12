# CodeGraph Integration

**跨语言代码图 fallback** — 当 TokenSave 不可用时提供代码图查询能力。

---

## 定位

**TokenSave 是主代码图工具**，CodeGraph 是其 fallback。仅在以下场景使用：
- TokenSave 未安装或不支持当前项目语言
- 需要跨语言代码图查询（TokenSave 主要支持 Rust）

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
| `codegraph_context` | **主要** — "X 如何工作"，获取综合上下文 |
| `codegraph_search` | 按名称定位符号 |
| `codegraph_callers` | 谁调用了此符号 |
| `codegraph_callees` | 此符号调用了谁 |
| `codegraph_impact` | 编辑影响面 |
| `codegraph_node` | 符号完整源码 |

---

## 工作流中的使用

### Phase 2 — 计划（代码图扫描）

当 TokenSave 不可用时使用 CodeGraph：

1. `codegraph_context` — 理解功能如何工作，获取相关代码
2. `codegraph_search` — 定位特定符号
3. `codegraph_callers` / `codegraph_callees` — 调用链
4. `codegraph_impact` — 评估编辑影响面
5. `codegraph_node` — 获取符号完整源码

### 关键原则

- **信任结果** — 不要使用 grep 重新验证。索引是预构建的。
- **将返回的源码视为已读取** — 无需重新读取文件。
- **编辑后检查 staleness banner** — 需要时重新索引。
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
- **TokenSave 关系**：TokenSave 是主工具；CodeGraph 是跨语言 fallback。
