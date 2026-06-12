# 工作留痕 (Worklog)

**每个 phase 完成后记录工作日志。两层存储：mempalace > 文件系统。**

最终目标：生成日报/周报/项目报告，有据可依。

## 存储层

| 层级 | 工具 | 用途 | 回退 |
|------|------|------|------|
| 1 | mempalace | 跨会话语义记忆（首选） | 文件系统 |
| 2 | `.doit/worklog.json` | 结构化日志文件 | 无 |

**写入逻辑：** 尝试 mempalace → 失败则文件系统。**至少一层成功。**

## 日志格式

每个 phase 完成后追加一条记录：

```json
{
  "session_id": "2026-06-07-abc123",
  "project": "myproject",
  "timestamp": "2026-06-07T10:30:00+08:00",
  "phase": "Phase 3 - Execute",
  "req": "REQ-001",
  "description": "实现用户认证 API，包括 login 和 register 端点",
  "duration_seconds": 1800,
  "status": "DONE",
  "files_modified": ["src/api/auth.rs", "tests/auth_test.rs"],
  "decisions": ["选择 JWT 而非 session token，因为移动端需要无状态认证"],
  "blockers": [],
  "test_results": "PASS (5/5)",
  "commit": "a1b2c3d"
}
```

## Phase 留痕点

| Phase | 记录内容 | 时机 |
|-------|---------|------|
| Phase 0 | 请求分类、类型判断 | 分类完成后 |
| Phase 1 | grill 问题数、用户回答、REQ 数量 | spec 写入后 |
| Phase 2 | 影响分析结果、实现顺序 | 计划完成后 |
| Phase 3 | 每个 REQ 的 TDD 结果、耗时 | 每个 REQ 完成后 |
| Phase 4 | E2E 测试结果 | E2E 完成后 |
| Phase 5 | Review 发现的问题 | Review 完成后 |
| Phase 6 | Simplify 删除的代码行数 | Simplify 完成后 |
| Phase 7 | E2E 验证结果、循环次数 | 验证完成后 |
| Phase 8 | 最终 commit hash、变更统计 | commit 完成后 |

## 写入实现

### 文件系统（回退层）

每个 phase 完成后，追加到 `.doit/worklog.json`：

```bash
# Phase 完成后执行
echo '{
  "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%S%z)'",
  "phase": "Phase 3 - Execute",
  "req": "REQ-001",
  "description": "实现用户认证 API",
  "duration_seconds": 1800,
  "status": "DONE",
  "files_modified": ["src/api/auth.rs"],
  "decisions": ["选择 JWT 而非 session token"],
  "blockers": [],
  "test_results": "PASS (5/5)",
  "commit": "a1b2c3d"
}' >> .doit/worklog.json
```

### MemPalace

```
mempalace_add_drawer wing="<project>" room="worklog" content="<JSON log entry>" source_file=".doit/worklog.json"
mempalace_diary_write agent_name="doit" entry="<compact summary>" topic="worklog"
```

## 报告生成

### 日报

```
# 日报 2026-06-07

## 完成工作
- [DONE] REQ-001: 实现用户认证 API (30min)
  - 文件: src/api/auth.rs, tests/auth_test.rs
  - 测试: PASS (5/5)
  - 决策: 选择 JWT 而非 session token

- [DONE] REQ-002: 创建用户配置 API (25min)
  - 文件: src/api/config.rs, tests/config_test.rs
  - 测试: PASS (3/3)

## 遇到的问题
- 无阻塞项

## 明日计划
- REQ-003: 集成认证中间件
- REQ-004: 添加速率限制

## 统计
- 总工时: 55min
- 完成 REQ: 2/4
- 代码变更: +320/-15 行
```

### 周报

汇总 5 天的日报，按项目/功能分组。

### 项目报告

从 worklog 中提取：
- 功能完成时间线
- 决策记录（为什么选 A 不选 B）
- 问题与解决方案
- 代码变更统计

## 铁律

**每个 phase 完成后必须记录工作日志。没有例外。**

- 记录失败（两层都不可用）→ 在 Phase 9.5 完成摘要中声明 `[WARN] worklog failed`
- 记录不阻塞工作流 → 即使记录失败也继续下一个 phase
- 记录内容要具体 → "实现认证 API" 而不是 "写代码"

## 配置

`.doit/config.yaml`:

```yaml
worklog:
  enabled: true          # 默认启用
  format: json           # json | markdown
  storage: auto          # auto (两层尝试) | mempalace | filesystem
  report:
    daily: true          # 生成日报
    weekly: false        # 生成周报
```
