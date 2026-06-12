# Headroom Integration

Headroom provides context optimization through **proxy compression** and **CCR (Compress-Cache-Retrieve)**.

**Important:** Headroom is NOT a memory layer. It compresses large tool outputs to save tokens. Memory management (list/export/import) is a separate CLI feature for backup/restore, not for runtime memory writes.

## Installation

```bash
# Install via uv
uv tool install "headroom-ai[mcp,proxy]"

# Register MCP server
headroom mcp install

# Verify
headroom --version
claude mcp list | grep headroom
```

## MCP Tools (Available in Workflow)

Headroom MCP provides these tools via `mcp__headroom__` prefix:

| Tool | Purpose |
|------|---------|
| `headroom_compress` | Compress large output to save tokens |
| `headroom_retrieve` | Retrieve original content from compressed hash |
| `headroom_stats` | Show compression statistics |

## Usage in Doit Workflow

### Phase 10 - Session Compression

Headroom compresses large session outputs for token-efficient storage:

1. **Compress session summary** (if output > threshold):
   - Use `headroom_compress` MCP tool on large tool outputs
   - Compressed content includes hash marker for retrieval

2. **Proxy Stats** (if proxy running):
   ```bash
   headroom proxy stats
   ```

### Proxy Mode (Optional)

For continuous token optimization during development:

```bash
# Start proxy
headroom proxy

# Use with Claude Code
ANTHROPIC_BASE_URL=http://127.0.1:8787 claude
```

When proxy is active, large tool outputs are automatically compressed before sending to the LLM. Claude sees compressed summaries with hash markers and can call `headroom_retrieve` to fetch full content when needed.

## Memory CLI (Backup/Restore Only)

Headroom has a local SQLite memory database for backup purposes. This is NOT used for runtime memory writes during the workflow.

```bash
# List memories (backup data only)
headroom memory list

# View stats
headroom memory stats

# Export for backup
headroom memory export --output backup.json

# Import from backup
headroom memory import backup.json

# Prune old memories
headroom memory prune --older-than 30d
```

**Note:** There is NO `headroom memory add` command. Memories are created by the proxy/CCR system automatically, not via CLI.

## Integration Points

| Phase | Headroom Action |
|-------|----------------|
| Phase 3-8 | Compress large tool outputs via `headroom_compress` |
| Phase 10 | Show compression stats via `headroom_stats` |
| Phase -1 | Proxy health check (optional) |
| doctor.sh | Installation verification |

## What Headroom is NOT

- NOT a cross-session memory layer (use MemPalace)
- NOT a knowledge graph (use MemPalace KG)
- NOT a code graph tool (use TokenSave)
- IS a token optimization layer via output compression
