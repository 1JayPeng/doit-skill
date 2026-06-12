# Tool Parameter Reference — 工具参数速查表

**[LOAD] 当出现 InputValidationError 时读取。平时不加载。**

每个工具的必需参数、常见错误、正确用法。

## Read

| Field | Required | Type | Note |
|-------|----------|------|------|
| `file_path` | **YES** | string (absolute path) | Must be absolute, not relative |
| `offset` | No | integer | Line number to start (0-indexed) |
| `limit` | No | integer | Number of lines to read |
| `pages` | No | string | PDF only: "1-5", "3", "10-20" (max 20) |

**Common Errors:**
- `InputValidationError: file_path is missing` — Forgot to pass `file_path`. Always use absolute path.
- For large files (>2000L), use `ctx_read(path, "aggressive")` or `ctx_read(path, "map")` instead.

**Correct:**
```
Read({ file_path: "/abs/path/to/file.rs" })
Read({ file_path: "/abs/path/to/file.pdf", pages: "1-5" })
```

## Edit

| Field | Required | Type | Note |
|-------|----------|------|------|
| `file_path` | **YES** | string (absolute path) | Must have been Read first |
| `old_string` | **YES** | string | Exact text to find (must be unique in file) |
| `new_string` | **YES** | string | Replacement text |
| `replace_all` | No | boolean | Default false |

**Common Errors:**
- `InputValidationError: file_path is missing` — Read the file first, then edit
- `InputValidationError: old_string is missing` — Must provide exact text to match
- Edit fails if `old_string` matches 0 or >1 times — make it more unique with surrounding context

**Fallback:** If Edit requires Read and Read is unavailable, use `ctx_edit(path, old_string, new_string)`.

**Correct:**
```
Edit({ file_path: "/abs/path/file.rs", old_string: "fn old()", new_string: "fn new()" })
```

## Bash

| Field | Required | Type | Note |
|-------|----------|------|------|
| `command` | **YES** | string | Shell command to execute |
| `timeout` | No | number | Max 600000ms (10 min), default 120000ms |
| `run_in_background` | No | boolean | Run in background |
| `description` | No | string | Human-readable description |

**Common Errors:**
- `InputValidationError: command is missing` — Most common! Empty `command` parameter.
- **Root cause:** Model generates tool call before constructing the command in thinking.

**Mandatory Preflight (from rules.md):**
```
[BASH PREFLIGHT]
cmd: <complete, executable command text>
Reason: <why, one sentence>
```
Only generate Bash call after `[BASH PREFLIGHT]` appears in thinking with complete `cmd:` line.

**Correct:**
```
Bash({ command: "cargo test --lib" })
Bash({ command: "git status", description: "Show working tree status" })
```

## Write

| Field | Required | Type | Note |
|-------|----------|------|------|
| `file_path` | **YES** | string (absolute path) | Must be absolute |
| `content` | **YES** | string | Full file content |

**Common Errors:**
- `InputValidationError: file_path is missing`
- Write fails on existing file if never Read first — Read the file first.

**Correct:**
```
Write({ file_path: "/abs/path/new-file.md", content: "# Title\n..." })
```

## TaskCreate

| Field | Required | Type | Note |
|-------|----------|------|------|
| `subject` | **YES** | string | Brief title |
| `description` | **YES** | string | What needs to be done |
| `activeForm` | No | string | Present continuous for spinner |

**Common Errors:**
- `InputValidationError: subject is missing` — Must provide both `subject` AND `description`

**Correct:**
```
TaskCreate({ subject: "Phase 3 - Execute", description: "TDD per REQ" })
```

## TaskUpdate

| Field | Required | Type | Note |
|-------|----------|------|------|
| `taskId` | **YES** | string | ID from TaskCreate result |
| `status` | No | string | "pending", "in_progress", "completed" or "deleted" |

**Common Errors:**
- `InputValidationError: taskId is missing` — After compact, taskId is lost from context.
- **Do NOT retry.** See [errors.md](errors.md)#compact-后-task-丢失.

**Correct:**
```
TaskUpdate({ taskId: "3", status: "completed" })
```

## Agent

| Field | Required | Type | Note |
|-------|----------|------|------|
| `description` | **YES** | string | Short (3-5 word) description |
| `prompt` | **YES** | string | Full task instructions |
| `subagent_type` | No | string | "general-purpose", "claude", "Plan", "Explore" |
| `run_in_background` | No | boolean | Default false |
| `isolation` | No | string | "worktree" for git isolation |
| `model` | No | string | Override model — **DO NOT USE** |

**Common Errors:**
- `InputValidationError: description is missing` — Both `description` AND `prompt` required
- **Never specify `model` parameter** — inherits from parent, specifying causes model-not-found errors

**Correct:**
```
Agent({
  description: "Implement REQ-001",
  prompt: "Full instructions...",
  subagent_type: "general-purpose",
  isolation: "worktree",
  run_in_background: true
})
```

## AskUserQuestion

| Field | Required | Type | Note |
|-------|----------|------|------|
| `questions` | **YES** | array (1-4 items) | Each: {question, header, options, multiSelect} |
| `questions[].question` | **YES** | string | Ends with ? |
| `questions[].header` | **YES** | string | Max 12 chars |
| `questions[].options` | **YES** | array (2-4 items) | {label, description} |
| `questions[].multiSelect` | **YES** | boolean | true = multiple selection |

**Common Errors:**
- `InputValidationError: questions is missing` — Must be array of question objects
- Each question needs `question`, `header`, `options`, `multiSelect`

**Correct:**
```
AskUserQuestion({
  questions: [{
    question: "Which approach?",
    header: "Approach",
    options: [
      { label: "A (Recommended)", description: "Fast, simple" },
      { label: "B", description: "More flexible" }
    ],
    multiSelect: false
  }]
})
```

## lean-ctx ctx_read

| Field | Required | Type | Note |
|-------|----------|------|------|
| `path` | **YES** | string | Absolute file path |
| `mode` | No | string | auto\|full\|map\|signatures\|diff\|aggressive\|task\|reference\|lines:N-M |
| `fresh` | No | boolean | Bypass cache |

**Correct:**
```
ctx_read({ path: "/abs/path/file.rs", mode: "aggressive" })
ctx_read({ path: "/abs/path/file.rs", mode: "lines:100-200" })
```

## lean-ctx ctx_edit

| Field | Required | Type | Note |
|-------|----------|------|------|
| `path` | **YES** | string | Absolute or project-relative |
| `new_string` | **YES** | string | Replacement text |
| `old_string` | **YES** (unless `create: true`) | string | Exact text to find |
| `create` | No | boolean | If true, create new file |

**Advantage over native Edit:** Does NOT require prior Read. Good fallback when Read is broken.

**Correct:**
```
ctx_edit({ path: "src/file.rs", old_string: "old", new_string: "new" })
ctx_edit({ path: "new-file.rs", create: true, new_string: "content" })
```

## MCP Tool Calling Pattern

**All MCP tools use JSON parameters. Common mistake: missing required fields.**

When a tool call fails with InputValidationError:
1. Check the tool signature above
2. Verify ALL required parameters are present
3. For Bash: ensure `[BASH PREFLIGHT]` was done
4. For Edit: ensure Read was called first
5. For TaskUpdate after compact: skip and clean up task list

**Never retry the same failed tool call with the same parameters.**
