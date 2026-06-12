# Headroom Integration

**Headroom** — 60-95% token 节省的压缩层，6 种压缩算法，可逆压缩（CCR 架构）。

## Proxy 模式（推荐）

**自动压缩所有工具输出，零代码改动，60-95% token 节省。**

```bash
# 启动 proxy
headroom proxy --port 8787 &
export ANTHROPIC_BASE_URL=http://127.0.0.1:8787

# 验证
curl -s http://127.0.0.1:8787/health | jq .

# 查看统计
headroom proxy stats

# 停止 proxy
kill $(cat /tmp/headroom-proxy.pid 2>/dev/null) 2>/dev/null || true
```

**效果：**
| 场景 | 压缩前 | 压缩后 | 节省 |
|------|--------|--------|------|
| 代码搜索 | 17,000 tokens | 1,400 tokens | 91% |
| 调试日志 | 65,000 tokens | 5,000 tokens | 92% |
| GitHub issue | 54,000 tokens | 14,000 tokens | 74% |

**工作原理：** Proxy 拦截所有 LLM 请求，在发送前自动压缩工具输出、日志、RAG 块、文件内容。原数据本地缓存，LLM 可通过 `headroom_retrieve` 按需检索。

## 6 种压缩算法

| 算法 | 内容类型 | 节省 |
|------|---------|------|
| **SmartCrusher** | JSON | 70-90% |
| **CodeCompressor** | 源代码 (AST) | 60-85% |
| **Log Dedup** | 日志文件 | 80-95% |
| **Search Ranking** | 搜索结果 | 70-90% |
| **ModernBERT** | 文本/ prose | 60-80% |
| **Git-diff Hunk** | 代码变更 | 50-70% |

Proxy 自动根据内容类型选择最优算法。

## MCP 工具

| 工具 | 用途 |
|------|------|
| `headroom_compress` | 压缩大输出，返回 hash + 摘要 |
| `headroom_retrieve` | 通过 hash 还原完整内容 |
| `headroom_stats` | 显示压缩统计信息 |

**Proxy 模式覆盖 MCP 模式** — proxy 更优因为零手动操作。MCP 工具仅用于非 proxy 场景。

## Persistent Memory

跨会话分层记忆，时间感知，智能作用域。

```bash
# 查看记忆
headroom memory list
# 导出备份
headroom memory export --output backup.json
# 清理旧记忆
headroom memory prune --older-than 30d
```

## 工作流集成点

| 阶段 | Headroom 动作 |
|------|--------------|
| **Phase 0** | 检测 Proxy 状态，公告 `[PROXY] headroom active` |
| **Phase 3-8** | Proxy 模式自动压缩所有工具输出 |
| **Phase 10** | `headroom_stats` + `headroom proxy stats` 显示统计 |
| **setup.sh** | 交互式 Proxy 配置 + 启动 |

## 安装

```bash
# 安装
uv tool install "headroom-ai[mcp,proxy]"
# 注册 MCP
headroom mcp install
# 验证
headroom --version
claude mcp list | grep headroom
```

## Headroom 不是
- NOT 跨会话记忆层（用 MemPalace）
- NOT 知识图谱（用 MemPalace KG）
- NOT 代码图工具（用 TokenSave）
- IS token 优化层，通过 Proxy 自动压缩所有工具输出
