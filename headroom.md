# Headroom Integration

**Headroom** — 60-95% token 节省的压缩层，6 种压缩算法，可逆压缩（CCR 架构）。

## 架构：Proxy + Fallback

```
Claude Code → Headroom Proxy (port 8787) → Upstream (settings.json ANTHROPIC_BASE_URL)
                      ↓
              自动压缩工具输出
              60-95% token 节省
```

**关键设计：settings.json 的 `ANTHROPIC_BASE_URL` 永远指向原始上游**（例如 `localhost:8000` 本地模型或 `api.anthropic.com` 云端）。Proxy 通过 `ANTHROPIC_TARGET_API_URL` 读取该值作为上游。如果 Proxy 不可用，settings.json 的值自动回退生效。

## 持久化部署

setup.sh 使用 `headroom install apply` 创建持久化服务，取代临时后台进程：

```bash
# setup.sh Step 3.7 执行（需要 ANTHROPIC_TARGET_API_URL 环境变量）
ANTHROPIC_TARGET_API_URL="http://localhost:8000" \
  headroom install apply \
    --preset persistent-service \
    --runtime python \
    --scope user \
    --target claude \
    --port 8787
```

**效果：**
| 场景 | 压缩前 | 压缩后 | 节省 |
|------|--------|--------|------|
| 代码搜索 | 17,000 tokens | 1,400 tokens | 91% |
| 调试日志 | 65,000 tokens | 5,000 tokens | 92% |
| GitHub issue | 54,000 tokens | 14,000 tokens | 74% |

## 运行时回退机制

Phase 0 检测 Proxy 状态，按优先级降级：

1. `ANTHROPIC_BASE_URL` 包含 `127.0.0.1:8787` → `[PROXY] headroom active`
2. `curl -sf http://127.0.0.1:8787/health` 成功 → `[PROXY] headroom active`
3. Proxy 不运行但 config 启用 → `[PROXY-FALLBACK]` 使用上游（settings.json 值）
4. Proxy 未配置 → 安静跳过（MCP 工具仍可用）

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

## MCP 工具（Fallback）

| 工具 | 用途 |
|------|------|
| `headroom_compress` | 压缩大输出，返回 hash + 摘要 |
| `headroom_retrieve` | 通过 hash 还原完整内容 |
| `headroom_stats` | 显示压缩统计信息 |

**MCP 工具是 Proxy 不可用时的 fallback** — Agent 可以手动调用压缩，但效果远不如自动拦截。

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
| **Phase 0** | 检测 Proxy 健康 + 回退状态 |
| **Phase 3-8** | Proxy 模式自动压缩所有工具输出（如果可用） |
| **Phase 10** | `headroom_stats` 显示统计 |
| **setup.sh** | 持久化部署 `headroom install apply` |
| **doctor.sh** | 检查 Proxy 运行状态 + 回退配置 |

## 安装

```bash
# 安装
uv tool install "headroom-ai[mcp,proxy]"
# 注册 MCP（fallback 工具）
headroom mcp install
# 持久化部署 Proxy（setup.sh Step 3.7 自动完成）
headroom install apply --preset persistent-service --runtime python --scope user --target claude
# 验证
headroom install status
curl -s http://127.0.0.1:8787/health | jq .
```

## Headroom 不是
- NOT 跨会话记忆层（用 MemPalace）
- NOT 知识图谱（用 MemPalace KG）
- NOT 代码图工具（用 CodeGraph）
- IS token 优化层，通过 Proxy 自动压缩所有工具输出，MCP 工具作为 fallback
