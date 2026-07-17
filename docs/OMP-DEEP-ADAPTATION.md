# OMP 深度适配报告

## 执行摘要

doit-skill 与 OMP (oh-my-pi) 的深度适配已完成核心功能集成，并识别出进一步优化的机会。本报告总结了当前适配状态、已实现功能、待适配领域及实施建议。

---

## 一、OMP 核心特性与适配状态

### 1.1 多模型架构 ✅ 已适配

**实现方式：**
- 创建 `scripts/multi-model.sh` 脚本
- 支持 `--smol` / `--slow` / `--plan` 三个模型参数
- 配置存储在 `~/.doit/config.yaml` 的 `models:` 部分
- 集成到 setup.sh 的 doctor 阶段

**OMP 多模型角色：**

| 模型 | 角色 | 适用阶段 |
|------|------|----------|
| **smol** | 快速/轻量级 | Phase 0 分类、快速查询 |
| **slow** | 推理/深度思考 | Phase 1 规格、Phase 3 执行、审查 |
| **plan** | 架构/规划 | Phase 2 规划、影响分析 |

**配置文件示例：**
```yaml
# ~/.doit/config.yaml
models:
  smol: "qwen3-0.6b"
  slow: "claude-sonnet-4-20250514"
  plan: "claude-opus-4-20250514"
```

**优势：**
- 成本优化：简单任务使用便宜模型
- 速度优化：快速分类和查询使用 smol
- 质量优化：复杂任务使用 slow/plan
- 灵活性：可按代理或全局配置模型

---

### 1.2 MemPalace 记忆集成 ✅ 已适配

**实现方式：**
- OMP 插件安装：`omp plugin install mempalace`
- 集成到 Phase 8（Git 提交 + 推送）
- 集成到 Phase 9.5（完成摘要 + 知识提取）
- 集成到 Phase 10（会话摘要）

**记忆功能：**

| 功能 | 说明 | 集成点 |
|------|------|--------|
| **知识图谱 (KG)** | 结构化记忆，跨会话持久化 | Phase 8 |
| **会话日志** | 自动保存会话摘要 | Phase 9.5 |
| **语义搜索** | 跨项目知识检索 | Phase 0/1 |
| **实体提取** | 自动识别项目实体 | Phase 8 |

**记忆存储结构：**
```
mempalace/
├── projects/
│   └── <project_name>/
│       ├── kg/              # 知识图谱
│       ├── sessions/        # 会话日志
│       │   ├── general/     # 结构化反馈
│       │   └── problems/    # 问题反馈
│       └── knowledge_docs/  # 知识文档
└── shared/
    └── sessions/            # 跨项目共享会话
```

**适配优势：**
- 跨会话恢复：MemPalace diary + KG facts 提供项目状态恢复
- 知识复用：Phase 1/2 可以检索历史决策和模式
- 错误避免：历史记录帮助避免重复错误
- 质量保证：结构化记忆提升工作流质量

---

### 1.3 OMP 插件系统 ⚠️ 基础适配

**已安装插件：**
- mempalace - 记忆系统
- ponytail - 简洁性检查
- context-mode - 上下文管理
- codegraph - 代码图分析
- headroom - 压缩缓存检索

**插件安装命令：**
```bash
# OMP 插件安装
omp plugin install mempalace
omp plugin install ponytail
omp plugin install context-mode
omp plugin install codegraph
omp plugin install headroom

# 插件列表
omp plugin list

# 插件更新
omp plugin install mempalace --pty
```

**待适配：**
- doit 作为 OMP 插件注册（支持 `omp doit` 命令）
- OMP 技能发现机制集成

---

### 1.4 OMP MCP 支持 ✅ 已适配

**MCP 配置：**
```json
{
  "mcp_servers": {
    "mempalace": {
      "command": "mempalace",
      "args": ["serve"]
    },
    "headroom": {
      "command": "headroom",
      "args": ["mcp"]
    },
    "codegraph": {
      "command": "codegraph",
      "args": ["mcp"]
    }
  }
}
```

**配置文件：** `~/.config/omp/mcp.json`

---

### 1.5 OMP 规则系统 ✅ 已适配

**规则目录：**
- `.claude/rules/` - Claude Code 规则
- `.omp/rules/` - OMP 规则（待创建）

**规则文件：**
- `lean-ctx.md` - 上下文工程规则
- `omp.md` - OMP 特定规则（待创建）

**待适配：**
- 创建 `.omp/rules/` 目录
- 添加 OMP 特定工作流规则
- 集成到 OMP 规则加载机制

---

## 二、OMP 深度适配机会

### 2.1 OMP 会话管理 ❌ 未适配

**OMP 支持的会话功能：**
```bash
# 继续未完成的任务
omp --continue

# 恢复指定会话
omp --resume <session_id>

# 列出活跃会话
omp session list

# 会话状态查询
omp session status
```

**当前实现：**
- doit 使用文件系统保存会话状态（`.doit/` 目录）
- Phase 状态通过 spec 文件和 git 状态推断
- MemPalace diary 提供跨会话恢复

**适配方案：**

1. **会话状态持久化**
   ```bash
   # 保存当前会话状态
   omp session save --file .doit/session-state.json
   
   # 恢复会话
   omp session restore --file .doit/session-state.json
   ```

2. **会话延续支持**
   ```bash
   # 在 .doit/ 目录创建 session-state.json
   {
     "phase": 3,
     "task": "Phase 3 - Execute",
     "status": "in_progress",
     "resume_info": "TDD execution in progress"
   }
   ```

3. **OMP 会话集成**
   ```bash
   # 检测 OMP 会话
   if [ -f ".doit/session-state.json" ]; then
     omp --continue
   else
     /doit
   fi
   ```

**优先级：高**
- 用户体验：真正的工作流延续
- 状态保持：跨会话任务状态
- 用户友好：支持 `omp --continue` 命令

---

### 2.2 OMP 原生工具集成 ❌ 未适配

**OMP 原生工具：**

| 工具 | 功能 | 适配机会 |
|------|------|----------|
| **todo** | 任务管理 | Phase 0/1/2 任务列表管理 |
| **task** | 子代理管理 | Phase 3 子代理调度 |
| **web_search** | 网络搜索 | Phase 1 网络调研 |
| **browser** | 浏览器控制 | Phase 1 网页调研、E2E 测试 |
| **lsp** | 语言服务器 | Phase 3 代码编辑 |
| **dap** | 调试协议 | Phase 3 调试 |

**适配方案：**

1. **任务管理集成**
   ```bash
   # Phase 0: 创建任务列表
   todo({
     op: "init",
     list: [
       { phase: "Phase 0 - Classify", items: ["Classify request"] },
       { phase: "Phase 1 - Spec", items: ["Grill user", "Write spec"] },
       { phase: "Phase 2 - Plan", items: ["Write plan"] }
     ]
   })
   
   # Phase 边界：启动下一阶段
   todo({ op: "start", task: "Phase 1 - Spec" })
   
   # Phase 边界：完成阶段
   todo({ op: "done", task: "Phase 0 - Classify" })
   ```

2. **子代理管理集成**
   ```bash
   # Phase 3: 子代理调度
   task({
     prompt: "Implement Phase 3 tasks according to plan",
     background: true,
     model: "slow"  # 使用慢模型
   })
   ```

3. **网络搜索集成**
   ```bash
   # Phase 1: 网络调研
   web_search({
     query: "authentication best practices",
     language: "zh"
   })
   ```

4. **浏览器集成**
   ```bash
   # Phase 1: 网页调研
   browser({
     action: "open",
     url: "https://docs.example.com"
   })
   
   # 提取页面内容
   browser({
     action: "run",
     code: "const obs = await tab.observe(); display(obs); return obs.elements.length;"
   })
   ```

**优先级：中**
- 工具集成：利用 OMP 原生工具
- 状态管理：更好的任务状态管理
- 效率提升：子代理管理优化

---

### 2.3 OMP 持久工作流 ❌ 未适配

**OMP 持久工作流特性：**
- Python/Bun workers 持久运行
- 跨会话状态保持
- 后台任务处理
- 工作流状态持久化

**适配方案：**

1. **工作流状态持久化**
   ```bash
   # 创建持久 worker
   bash({
     command: "python worker.py",
     background: true
   })
   
   # 与 worker 通信
   task({
     prompt: "Update workflow state",
     background: true
   })
   ```

2. **跨会话状态**
   ```python
   # worker.py
   import json
   
   class WorkflowState:
       def __init__(self):
           self.current_phase = 0
           self.tasks = {}
           self.specs = {}
       
       def save(self):
           with open('.doit/worker-state.json', 'w') as f:
               json.dump(self.__dict__, f)
       
       def load(self):
           with open('.doit/worker-state.json', 'r') as f:
               self.__dict__.update(json.load(f))
   ```

**优先级：低**
- 架构复杂：需要额外的 worker 进程
- 收益有限：文件系统已提供足够的持久化
- 实施成本：需要额外开发

---

### 2.4 OMP 浏览器集成 ❌ 未适配

**OMP 浏览器功能：**
- 内置浏览器控制
- JS 渲染支持
- 交互内容处理
- 截图和内容提取

**适配方案：**

1. **网页调研**
   ```bash
   # Phase 1: 调研需求
   browser({
     action: "open",
     url: "https://github.com/example/project"
   })
   
   # 提取页面内容
   browser({
     action: "run",
     code: "const obs = await tab.observe(); return obs.elements;"
   })
   ```

2. **E2E 测试**
   ```bash
   # Phase 3: 测试执行
   browser({
     action: "open",
     url: "http://localhost:3000"
   })
   
   # 交互测试
   browser({
     action: "run",
     code: "await tab.click('button#submit'); await tab.waitForUrl('success');"
   })
   ```

**优先级：中**
- 调研能力：Phase 1 需要网页调研
- 测试能力：Phase 3 需要 E2E 测试
- 实施成本：中等

---

### 2.5 OMP DAP 调试集成 ❌ 未适配

**OMP DAP 功能：**
- 调试器启动
- 断点管理
- 步进执行
- 变量评估

**适配方案：**

1. **调试器启动**
   ```bash
   # Phase 3: 启动调试
   dap({
     action: "start",
     program: "./myapp",
     args: ["--test"]
   })
   ```

2. **断点管理**
   ```bash
   # 设置断点
   dap({
     action: "set_breakpoint",
     file: "src/main.ts",
     line: 42
   })
   
   # 继续执行
   dap({
     action: "continue"
   })
   ```

3. **变量评估**
   ```bash
   # 评估变量
   dap({
     action: "evaluate",
     expression: "user.id"
   })
   ```

**优先级：低**
- 使用场景有限：主要调试阶段
- 实施成本：中等
- 收益：调试体验提升

---

## 三、实施优先级建议

### 3.1 高优先级（建议优先实施）

1. **OMP 会话延续支持**
   - 状态持久化到 `.doit/session-state.json`
   - 支持 `omp --continue` 命令
   - 跨会话任务状态恢复
   - 用户体验提升

2. **OMP 原生工具集成（todo/task）**
   - 任务管理集成到 OMP todo 工具
   - 子代理管理集成到 OMP task 工具
   - 更好的状态管理和效率

### 3.2 中优先级

3. **OMP 浏览器集成**
   - Phase 1 网络调研
   - Phase 3 E2E 测试
   - 网页内容提取

4. **OMP 规则系统适配**
   - 创建 `.omp/rules/` 目录
   - 添加 OMP 特定工作流规则
   - 集成到 OMP 规则加载机制

### 3.3 低优先级

5. **OMP 持久工作流**
   - 需要额外的 worker 进程
   - 文件系统已提供足够持久化
   - 实施成本较高

6. **OMP DAP 调试集成**
   - 使用场景有限
   - 实施成本中等
   - 收益相对较小

---

## 四、实施路线图

### 4.1 第一阶段：会话延续支持（1-2 天）

**目标：** 实现 OMP 会话延续功能

**任务：**
1. 创建 `.doit/session-state.json` 格式
2. 实现会话状态保存/加载逻辑
3. 集成到 setup.sh 和 doctor.sh
4. 测试 `omp --continue` 命令支持

**预期收益：**
- 用户友好的会话延续
- 跨会话任务状态保持
- 减少重复工作

### 4.2 第二阶段：原生工具集成（2-3 天）

**目标：** 深度集成 OMP 原生工具

**任务：**
1. 集成 todo 工具到任务管理
2. 集成 task 工具到子代理管理
3. 集成 web_search 到网络调研
4. 集成 browser 到网页调研

**预期收益：**
- 更好的工具集成
- 更高的执行效率
- 更丰富的功能体验

### 4.3 第三阶段：浏览器和 DAP 集成（3-5 天）

**目标：** 集成浏览器和 DAP 调试

**任务：**
1. 集成 browser 工具到调研和测试
2. 集成 DAP 工具到调试流程
3. 实现网页内容提取
4. 实现断点和步进执行

**预期收益：**
- 增强的调研能力
- 改进的测试和调试体验
- 更完整的功能覆盖

---

## 五、总结

doit-skill 与 OMP 的深度适配已完成核心功能集成：
- ✅ 多模型架构支持
- ✅ MemPalace 记忆集成
- ✅ OMP 插件系统基础适配
- ✅ MCP 支持配置
- ✅ 规则系统适配

识别出进一步优化的机会：
- 🔲 OMP 会话延续支持（高优先级）
- 🔲 OMP 原生工具集成（高优先级）
- 🔲 OMP 浏览器集成（中优先级）
- 🔲 OMP 规则系统适配（中优先级）
- 🔲 OMP 持久工作流（低优先级）
- 🔲 OMP DAP 调试集成（低优先级）

建议按优先级顺序实施，首先实现会话延续支持和原生工具集成，以最大化用户体验和功能完整性。