# Phase 4: End-to-End Testing

**核心理念：E2E 测试 = 模拟用户从程序总入口开始的完整行为。**

不是单元测试。不是集成测试。不是调用内部函数。是 **从程序入口（CLI / API / GUI）启动程序，像真实用户一样操作它，观察最终输出。**

## E2E 测试定义

**一个合法的 E2E 测试必须满足：**

1. **从总入口启动** — 程序的可执行入口（`python -m main`、`node dist/index.js`、`curl http://localhost:3000/api/...`、用户在浏览器中点击按钮）
2. **模拟用户行为** — 用户输入命令、发送请求、点击界面、上传文件 — 一切通过程序对外暴露的接口
3. **观察用户可见输出** — 退出码、标准输出/错误、生成的文件、数据库记录、页面内容 — 用户能看到的
4. **不导入任何内部模块** — 绝不 `from internal import helper`，绝不 `import services.db`。如果只能通过 import 内部模块才能测试 → 那不是 E2E

## 铁律

- **E2E 运行在真实环境中**（uv venv、真实数据库、真实文件系统）
- **每一个入口必须测试。每一个入口参数必须测试。**
- **如果自动化困难 → HITL（交给用户手动验证）**
- **禁止 mock 外部依赖。** 数据库、网络、文件系统 — 全部真实的

## E2E vs 单元测试 — 对比示例

### ❌ 这不是 E2E（单元测试）
```python
# 直接调用内部函数 — 绕过入口
from src.auth import validate_login
assert validate_login("user", "pass") == True

# import 内部模块 — 不是从入口开始
from src.service import UserService
UserService().create_user("test")

# 只是把 subprocess 换了壳，但断言的是内部状态
result = subprocess.run(["python", "-m", "main", "--cmd", "run"])
assert result.stdout  # 太模糊，没验证用户实际看到的
```

### ✅ 这是 E2E（从入口模拟用户）
```python
# CLI 程序 — 用户从终端敲命令
result = subprocess.run(
    ["python", "-m", "main", "login", "--user", "test", "--pass", "abc123"],
    capture_output=True, text=True, cwd="."
)
assert result.returncode == 0          # 用户看到成功
assert "Welcome back" in result.stdout  # 用户看到欢迎语
assert "token=" in result.stderr        # 用户拿到 token

# API 服务 — 用户通过 HTTP 请求
import requests
resp = requests.post("http://localhost:3000/api/login", json={"user": "test", "pass": "abc123"})
assert resp.status_code == 200
assert resp.json()["token"]
assert "Welcome" in open("/tmp/dashboard.html").read()

# Web 应用 — 用户通过浏览器操作（Playwright）
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page()
    page.goto("http://localhost:3000")
    page.fill("#username", "test")
    page.fill("#password", "abc123")
    page.click("#login-btn")
    page.wait_for_selector("#dashboard")  # 用户看到仪表盘
    assert "Welcome" in page.text_content("h1")
```

## 测试级别分类

| 级别 | 场景 | 自动 |
|------|------|------|
| L0 | 必选参数，幸福路径 — 用户正常使用 | 是 |
| L1 | 边界值（空、超长、特殊字符）— 用户乱输入 | 是 |
| L2 | 冲突参数组合 — 用户误操作 | HITL |
| L3 | 模糊/随机输入，稳定性 — 用户恶意测试 | HITL |

## Tool Calling

### Run E2E Tests

**Primary (fast path — only affected tests):**
```
tokensave_affected_tests(files=[<changed_files>])
tokensave_run_affected_tests(changed_paths=[<changed_files>])
```
If `affected_tests` returns all tests (no narrowing), fall back to full suite.

**Fallback (full suite):**
```
ctx_execute(language="shell", code="uv run pytest tests/e2e/ -v --tb=short")
ctx_execute(language="shell", code="uv run python -m pytest tests/e2e/ -v --tb=short")
```
- **Context-Mode unavailable:** native Bash tool (output not indexed).

### Detect Test Framework (before generating tests)

Scan project config to determine the test runner:
```
ctx_batch_execute(
  commands=[
    {"label": "pyproject.toml", "command": "cat pyproject.toml 2>/dev/null || echo missing"},
    {"label": "package.json scripts", "command": "cat package.json 2>/dev/null | grep -A5 scripts || echo missing"},
    {"label": "test dirs", "command": "find . -maxdepth 3 -type d -name test\* -o -name __tests__ 2>/dev/null | head -10"},
  ],
  queries=["pytest", "jest", "test runner", "test framework"]
)
```
- **Fallback:** If Context-Mode unavailable -> parallel Bash calls to `cat` + `find`.

**tokensave** tools for understanding entry points:
1. `tokensave_search(query="<entry_point_name>")` — find the entry point function
2. `tokensave_node(node_id="<id>")` — get function signature for test generation
3. `tokensave_signature(qualified_name="<entry_point>")` — get function signature without body
4. `tokensave_test_map(file="<source_file>")` — check existing test coverage
5. `tokensave_config(key="dependencies", path="Cargo.toml")` — read project config without file reads (TOML/JSON)
6. `tokensave_outline(file="<entry_point_file>")` — flat list of top-level symbols (quick file overview)
- **Fallback:** If TokenSave unavailable -> `grep -rn "def " src/` + `Read` the file.

### Spec Alignment Check Tools

After tests pass, compare output against spec:
1. `ctx_search(queries=[<REQ descriptions>])` — look up spec REQs from indexed content
   - **Fallback:** Read `.spec/current.md` directly.
2. `tokensave_diff_context(files=[<changed_files>])` — which symbols changed, semantic impact
   - **Fallback:** `git diff --name-only` + `git diff <file>`.

## L0/L1 自动生成

**步骤：找到程序入口 → 列出入口参数 → 生成 E2E 脚本**

1. **定位入口** — 找 `if __name__ == "__main__"`、CLI `entry_points`、API server `main()`、前端 `App.tsx`
2. **列出用户可见参数** — CLI 参数、HTTP 请求字段、表单输入
3. **生成 L0** — 每个入口一条幸福路径（用户正常使用）
4. **生成 L1** — 每个参数一个边界值（用户输入空串、超长、特殊字符）

```python
# E2E 骨架 — 从 CLI 入口启动，模拟用户敲命令
import subprocess, sys

def run_cli(*args):
    """从程序入口启动，完全模拟用户行为"""
    result = subprocess.run(
        [sys.executable, "-m", "main"] + list(args),
        capture_output=True, text=True, cwd="."
    )
    return result

# L0: 用户正常使用 — 登录
r = run_cli("login", "--user", "test", "--pass", "abc123")
assert r.returncode == 0
assert "Welcome" in r.stdout

# L1: 用户输入空用户名
r = run_cli("login", "--user", "", "--pass", "abc123")
assert r.returncode != 0  # 程序应拒绝
assert "error" in r.stderr.lower()

# L1: 用户输入超长密码
r = run_cli("login", "--user", "test", "--pass", "x" * 10000)
assert r.returncode != 0
assert "too long" in r.stderr.lower() or "invalid" in r.stderr.lower()
```

**关键：每个测试都是 `subprocess.run` 从入口启动。不 import 项目内部代码。**

## E2E 编写检查清单

**每写一个 E2E 测试，确认：**

- [ ] **从哪个入口启动？**（CLI 命令 / API 地址 / GUI URL）
- [ ] **用户做了什么操作？**（输入什么参数、点什么按钮、发什么请求）
- [ ] **用户看到了什么结果？**（退出码、输出文字、文件变化、数据库记录）
- [ ] **测试 import 了项目内部代码吗？** → 是 = 不是 E2E = 重写
- [ ] **测试 mock 了数据库/文件系统/网络？** → 是 = 不是 E2E = 用真实环境

## L2/L3 HITL

**铁律: Use AskUserQuestion, never stop and wait.**

向用户呈现未测试的参数组合：
```
AskUserQuestion:
  question: "Which param combos need manual e2e testing?"
  header: "E2E L2"
  options:
    - label: "Skip L2/L3 (Recommended)"
      description: "L0+L1 coverage is sufficient"
    - label: "Test --flag-a + --flag-b"
      description: "Conflict expected?"
    - label: "Test --mode=debug + --verbose"
      description: "Redundant?"
    - label: "Test all combos"
      description: "Run all L2/L3 combos"
```

If user selects a combo -> run it, capture output, generate assertion.
If user doesn't answer -> skip L2/L3, proceed with L0+L1.

## E2E + Spec Cross-Check

Compare e2e coverage against spec acceptance criteria. Missing -> flag to user.

## Long-Running E2E Tasks

E2E test suites often take >5 minutes (server startup, integration tests, multi-step workflows). Use tmux + monitor for auto-continuation:

```bash
tmux new-session -d -s "doit-e2e"
tmux send-keys -t "doit-e2e" '(
  echo "[START] $(date "+%Y-%m-%d %H:%M:%S") — E2E server startup"
  uv run python -m run_server &
  SERVER_PID=$!
  sleep 5  # wait for server to start

  echo "[START] $(date "+%Y-%m-%d %H:%M:%S") — E2E test suite"
  uv run pytest tests/e2e/ -v --tb=short
  EXIT_CODE=$?

  kill $SERVER_PID 2>/dev/null || true

  echo "[END] $(date "+%Y-%m-%d %H:%M:%S") — exit_code=$EXIT_CODE"
  exit $EXIT_CODE
) > .scratch/logs/e2e-full.log 2>&1' Enter

Monitor "Watch E2E completion" \
  "grep -q '\[END\]' .scratch/logs/e2e-full.log" \
  --interval 30
```

When the monitor fires, Claude Code reads the log, checks the exit code, and proceeds to Phase 5 (Review) if successful. See [background-process.md](background-process.md) for full patterns.

### Spec Alignment Check (per REQ)

**E2E tests are not just about code running — they verify output matches what the user asked for.**

For each REQ in `.spec/current.md`:

1. Read REQ description and expected behavior
2. Find the e2e test that covers this REQ
3. Run the test, capture actual output
4. **Compare actual output against spec expectation — not the test assertion**

```
REQ-001: "user can login and see dashboard"
  Expected: dashboard page with user greeting
  Actual:   "Welcome back, test" on /dashboard URL
  Match?    Yes

REQ-002: "unauthorized access returns 403"
  Expected: 403 error, no page content
  Actual:   401 error, login redirect
  Match?    No — wrong status code and behavior differs from spec
```

**Key: compare output against spec, not against test assertion.** The test assertion might have been changed to match wrong output (AI lying to itself). Always read the spec as the ground truth.

## Phase 5 Pre-flight Gate

Phase 5 must not start until Phase 4 produces `e2e: passed`. Verify: all L0+L1 e2e tests passed.

## MemPalace

**[MP-WRITE] File E2E results for cross-session reference:**
```
mempalace_add_drawer wing="<project>" room="e2e" content="Phase 4 E2E: L0+L1 passed/failed, L2+L3 HITL status, entry points tested: <list>"
```
MP unavailable -> skip silently. The e2e test results are already in the git commit history.

## E2E Verification Loop (Phase 7 / D5)

**Canonical source: [shared/e2e-verify.md](shared/e2e-verify.md)**

Both feature flow (Phase 7) and debug flow (D5) use the same E2E Verification Loop.
The shared file is the single source of truth — update rules there, not here.
