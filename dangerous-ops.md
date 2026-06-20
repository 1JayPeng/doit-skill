# 铁律 — 危险操作保护

**涉及数据或代码删除的操作，必须先通过 [[USER:ask]] 确认，然后执行。**

## 什么是危险操作

### 数据库
- `DROP TABLE` / `DROP DATABASE`
- `TRUNCATE TABLE`
- `DELETE` / `UPDATE` 无 `WHERE` 子句
- `ALTER TABLE ... DROP COLUMN`
- 任何 `--force` 或 `--no-prompt` 标志的数据库迁移

### 文件系统
- `rm -rf` / `rm -r`（递归删除）
- `rm -f`（强制删除）
- `mv` 到 `/dev/null`
- 删除包含未提交更改的文件

### Git
- `git push --force` / `git push --force-with-lease`
- `git reset --hard`
- `git checkout --`（丢弃工作区更改）
- `git clean -f` / `git clean -fd`

### 代码
- 删除包含业务逻辑的源文件
- 覆盖没有备份的配置文件

## 确认流程

```
[[USER:ask]]:
  question: "即将执行危险操作: [具体命令]。这将 [后果描述]。确认？"
  header: "危险操作"
  options:
    - label: "确认执行"
      description: "[命令] 将不可逆地 [后果]"
    - label: "取消"
      description: "跳过此操作"
    - label: "修改后确认"
      description: "添加安全限制（如 WHERE 子句、dry-run）"
```

## 子代理保护

子代理 prompt 必须包含：

```
铁律 — 危险操作保护：
- 禁止执行任何数据库删除操作（DROP, TRUNCATE, DELETE 无 WHERE）
- 禁止使用 rm -rf / rm -r / rm -f 删除文件
- 禁止 git push --force / git reset --hard
- 如需删除，先通过 [[USER:ask]] 确认
```

## Hook 配置（可选）

Phase -1 检测用户环境时，可以建议在 `[[CONFIG:settings-file]]` 中添加：

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "echo \"$INPUT\" | grep -qiE 'rm\\s+-[a-zA-Z]*f|DROP\\s+TABLE|TRUNCATE|git\\s+reset\\s+--hard|git\\s+push\\s+--force' && echo '[DANGEROUS-OP] Detected potentially destructive command. Confirm before executing.' || true"
          }
        ]
      }
    ]
  }
}
```

**Hook 不写入项目 settings.json。** Hook 配置通过 Phase -1 的环境检测写入用户全局配置，或者仅作为建议告知用户。

**原因：** 项目级 settings.json 会被 rsync 到用户项目，覆盖用户自己的 hook 配置。这违反了 skill 的"不污染用户项目"原则。

## 铁律遵守检查

Phase 5 Review 监督清单追加：

```
[ ] 无危险操作绕过确认（DROP, TRUNCATE, rm -rf, git force push）
```
