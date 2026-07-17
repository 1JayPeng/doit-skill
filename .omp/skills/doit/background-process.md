# Background Process Management

**铁律: 所有 >10s 任务必须用 tmux + 实时日志 + `/loop` 自动轮询。不允许空等。** See [core/iron-rules.md](core/iron-rules.md).

## 强制决策门控（运行前必须检查）

**在运行任何可能超过 10 秒的命令前，必须完成以下检查：**

```
□ 1. 估计运行时间：这个命令预计需要多久？
□ 2. >10s？→ tmux 命名 session + 实时日志 + `/loop` 轮询
□ 3. 日志包含 [START] 和 [END] 标记？
□ 4. `/loop` 轮询已设置？
□ 5. 计划后续工作：后台任务启动后，继续做什么？
```

**任何一项未检查 = 违反铁律。**

### 常见违例（禁止行为）

| 违例 | 正确做法 |
|------|---------|
| 运行 `cargo build --release` 后沉默等待 | tmux 启动 + `/loop` + 继续其他工作 |
| `tail -f` 日志文件来"看进度" | `/loop` 自动检查 `[END]` |
| 启动后台任务后不设轮询 | 每个 tmux session 必须有 `/loop` |
| 在长对话中忘记后台任务 | 用户问进度 → 立即检查 `.scratch/logs/` 和 `tmux list-sessions` |
| 用 shell `&` 代替 tmux | tmux 是唯一标准 |
| 不设 timeout | 所有后台任务必须有 timeout，默认 300s |

## 执行标准

| Tier | When | Mechanism |
|------|------|-----------|
| **Foreground** | <10s, simple commands | Direct Bash call |
| **Tmux + Loop** | >10s, all long tasks | Named tmux session + real-time log + `/loop` polling |

**Tmux 是唯一长任务标准。** 不用 shell `&`，不用 `run_in_background`。

## Tier 1: Foreground

Simple commands, run directly:
```bash
cargo check
pytest tests/unit/
```

## Tier 2: Tmux + Loop (所有长任务)

### 为什么 tmux 是唯一标准

| 特性 | tmux | shell & |
|------|------|---------|
| 实时日志 | log 文件持续写入，随时 `tail` 可读 | 输出缓冲，日志可能延迟 |
| 进程管理 | 独立 session，可 attach 查看 | 依赖 shell 进程组 |
| 崩溃恢复 | session 持久，可重新连接 | shell 退出进程丢失 |
| 多阶段 pipeline | split-window 多 pane 协同 | 需要手动编排 |
| 完成检测 | `[END]` 标记写入 log，`/loop` 轮询 | 需要 wait + trap |

### 标准启动模板

```bash
mkdir -p .scratch/logs

TMUX_SESSION="doit-<phase-name>"
tmux new-session -d -s "$TMUX_SESSION"

tmux send-keys -t "$TMUX_SESSION" '(
  echo "[START] $(date "+%Y-%m-%d %H:%M:%S") — <description>"
  <your-command-here>
  EXIT_CODE=$?
  echo "[END] $(date "+%Y-%m-%d %H:%M:%S") — exit_code=$EXIT_CODE"
  exit $EXIT_CODE
) > .scratch/logs/<name>.log 2>&1' Enter
```

### 标准轮询模板

```
/loop 检查 .scratch/logs/<name>.log 完成状态:
1. grep '\[END\]' .scratch/logs/<name>.log
2. 如果找到 [END]: tail -1 读取 exit_code → 报告结果 → 停止循环
3. 如果没找到: ScheduleWakeup delaySeconds=120 继续轮询
4. 如果超过 30min: 报告超时 → 停止循环
```

**轮询前压缩上下文：** 设置 `/loop` 后立即调用 `headroom_compress` 压缩当前对话上下文。长轮询任务可能持续数十分钟，不压缩会导致上下文窗口膨胀、下一轮对话启动慢。

**间隔选择指南:**
- **<5min 任务**: 30-60s 间隔
- **5-15min 任务**: 120-180s 间隔
- **>15min 任务**: 300-600s 间隔
- **不确定**: 120s 默认

**避免 300s 精确值** — 缓存 TTL 正好 5min。选 270s（缓存内）或 360s（承担缓存 misses）。

### 轮询期间必须做其他工作

**设置 tmux + `/loop` 后，必须立即继续其他工作。** 空等 loop 触发 = 违反铁律。

**标准轮询后流程：**
1. 设置 `/loop` 轮询
2. **调用 `headroom_compress` 压缩上下文** — 释放 token 空间
3. 继续其他 phase 工作或研究任务

## 带进度报告的长任务

对于没有自然进度输出的任务（编译器、测试运行器），添加时间进度报告：

```bash
tmux send-keys -t "$TMUX_SESSION" '(
  START_TIME=$(date +%s)
  echo "[START] $(date "+%Y-%m-%d %H:%M:%S") — cargo test --all"

  # 后台进度报告器
  (
    while true; do
      ELAPSED=$(( $(date +%s) - START_TIME ))
      if [ $ELAPSED -eq 60 ]; then
        echo "[PROGRESS] 1min elapsed — still running..."
      elif [ $ELAPSED -eq 180 ]; then
        echo "[PROGRESS] 3min elapsed — still running..."
      elif [ $ELAPSED -eq 300 ]; then
        echo "[PROGRESS] 5min elapsed — still running..."
      fi
      sleep 30
    done
  ) &
  PROGRESS_PID=$!

  cargo test --all
  EXIT_CODE=$?
  kill $PROGRESS_PID 2>/dev/null || true

  TOTAL_ELAPSED=$(( $(date +%s) - START_TIME ))
  echo "[PROGRESS] Complete in ${TOTAL_ELAPSED}s"
  echo "[END] $(date "+%Y-%m-%d %H:%M:%S") — exit_code=$EXIT_CODE"
  exit $EXIT_CODE
) > .scratch/logs/test.log 2>&1' Enter
```

## 多阶段 Pipeline

多阶段任务（如 E2E：启动服务器 → 等待 → 运行测试）使用 tmux split-window：

```bash
mkdir -p .scratch/logs
tmux new-session -d -s "doit-e2e"

# Pane 0: 启动服务器
tmux send-keys -t "doit-e2e:0" '(
  echo "[START] $(date "+%Y-%m-%d %H:%M:%S") — dev server"
  uv run python -m uvicorn main:app --host 127.0.0.1 --port 8765
  EXIT_CODE=$?
  echo "[END] $(date "+%Y-%m-%d %H:%M:%S") — exit_code=$EXIT_CODE"
  exit $EXIT_CODE
) > .scratch/logs/e2e-server.log 2>&1' Enter

# Pane 1: 等待后运行测试
tmux split-window -t "doit-e2e" -h
tmux send-keys -t "doit-e2e:1" 'sleep 10 && (
  echo "[START] $(date "+%Y-%m-%d %H:%M:%S") — E2E tests"
  uv run pytest tests/e2e/ -v --tb=short
  EXIT_CODE=$?
  echo "[END] $(date "+%Y-%m-%d %H:%M:%S") — exit_code=$EXIT_CODE"
  exit $EXIT_CODE
) > .scratch/logs/e2e-tests.log 2>&1' Enter

# 轮询测试完成
```

```
/loop 检查 E2E 测试完成:
1. grep '\[END\]' .scratch/logs/e2e-tests.log
2. 完成 → tail -1 读取结果 → 停止
3. 未完成 → ScheduleWakeup 120s
```

## 超时包装

```bash
tmux send-keys -t "$TMUX_SESSION" '(
  echo "[START] $(date "+%Y-%m-%d %H:%M:%S") — <description>"
  timeout <seconds> <your-command-here>
  EXIT_CODE=$?
  if [ $EXIT_CODE -eq 124 ]; then
    echo "[TIMEOUT] $(date "+%Y-%m-%d %H:%M:%S") — exceeded <seconds>s"
    exit 124
  fi
  echo "[END] $(date "+%Y-%m-%d %H:%M:%S") — exit_code=$EXIT_CODE"
  exit $EXIT_CODE
) > .scratch/logs/<name>.log 2>&1' Enter
```

## Tmux Session 管理

```bash
# 列出活跃 session
tmux list-sessions | grep doit-

# 检查 session 状态
tmux has-session -t "doit-<name>" 2>/dev/null && echo "running" || echo "done"

# 清理 session
tmux kill-session -t "doit-<name>" 2>/dev/null || true

# 中断运行中的 session
tmux send-keys -t "doit-<name>" C-c
```

## 退出信号约定

| 标记 | 含义 |
|------|------|
| `[START]` | 任务开始，带时间戳 |
| `[PROGRESS]` | 中间进度（可选，用于用户可见性） |
| `[END] exit_code=0` | 成功 |
| `[END] exit_code=N` | 失败（N != 0） |
| `[TIMEOUT]` | 超时 |

## 完整示例

### Phase 3: 长构建

```bash
mkdir -p .scratch/logs
TMUX_SESSION="doit-build"
tmux new-session -d -s "$TMUX_SESSION"
tmux send-keys -t "$TMUX_SESSION" '(
  echo "[START] $(date "+%Y-%m-%d %H:%M:%S") — cargo build --release"
  cargo build --release
  EXIT_CODE=$?
  echo "[END] $(date "+%Y-%m-%d %H:%M:%S") — exit_code=$EXIT_CODE"
  exit $EXIT_CODE
) > .scratch/logs/build.log 2>&1' Enter
```

```
/loop 检查 build.log 完成:
- grep '\[END\]' .scratch/logs/build.log
- 完成 → tail -1 读取 exit_code → 报告 → 停止
- 未完成 → ScheduleWakeup 60s
```

### Phase 4: E2E 测试

```bash
mkdir -p .scratch/logs
tmux new-session -d -s "doit-e2e"
tmux send-keys -t "doit-e2e:0" '(
  echo "[START] $(date "+%Y-%m-%d %H:%M:%S") — dev server"
  uv run python -m uvicorn main:app --host 127.0.0.1 --port 8765
) > .scratch/logs/e2e-server.log 2>&1' Enter

tmux split-window -t "doit-e2e" -h
tmux send-keys -t "doit-e2e:1" 'sleep 10 && (
  echo "[START] $(date "+%Y-%m-%d %H:%M:%S") — E2E tests"
  uv run pytest tests/e2e/ -v --tb=short
  EXIT_CODE=$?
  echo "[END] $(date "+%Y-%m-%d %H:%M:%S") — exit_code=$EXIT_CODE"
  exit $EXIT_CODE
) > .scratch/logs/e2e-tests.log 2>&1' Enter
```

```
/loop 检查 E2E 测试完成 → 完成后进入 Phase 5
```

### Phase 7: E2E 验证（简化后重新运行）

```bash
mkdir -p .scratch/logs
tmux new-session -d -s "doit-e2e-verify"
tmux send-keys -t "doit-e2e-verify" '(
  echo "[START] $(date "+%Y-%m-%d %H:%M:%S") — E2E verification"
  uv run pytest tests/e2e/ -v
  EXIT_CODE=$?
  echo "[END] $(date "+%Y-%m-%d %H:%M:%S") — exit_code=$EXIT_CODE"
  exit $EXIT_CODE
) > .scratch/logs/e2e-verify.log 2>&1' Enter
```

```
/loop 检查 e2e-verify.log 完成 → 全部通过则进入 Phase 8
```

## 日志保留

`.scratch/logs/` 中的日志在 Phase 9 清理。

## 降级：无 tmux

如果 tmux 不可用：
1. 用 `Bash run_in_background=true` + timeout
2. Claude Code 自动通知完成
3. 检查结果

```bash
# 降级方案：无 tmux
(
  echo "[START] $(date '+%Y-%m-%d %H:%M:%S') — <description>"
  <command>
  EXIT_CODE=$?
  echo "[END] $(date '+%Y-%m-%d %H:%M:%S') — exit_code=$EXIT_CODE"
  exit $EXIT_CODE
) > .scratch/logs/<name>.log 2>&1 &
```

```
/loop 检查 .scratch/logs/<name>.log 的 [END] 标记
```
