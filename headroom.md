# Headroom Integration

Headroom provides context optimization for LLM applications through proxy compression and memory persistence.

## Installation

```bash
# Install via uv tool
uv tool install "headroom-ai[mcp,proxy]"

# Register MCP server
headroom mcp install

# Verify
headroom --version
claude mcp list | grep headroom
```

## Usage in Doit Workflow

### Phase 10 - Session Compression
Headroom replaces `/compact` for session compression:

1. **Memory Save**: Store session summary in headroom memory
   ```bash
   headroom memory add --content "<session summary>" --scope SESSION
   ```

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
ANTHROPIC_BASE_URL=http://127.0.0.1:8787 claude
```

## Memory Management

```bash
# List memories
headroom memory list

# View stats
headroom memory stats

# Prune old memories
headroom memory prune --older-than 30d
```

## Integration Points

| Phase | Headroom Action |
|-------|----------------|
| Phase 10 | Session compression + memory save |
| Phase -1 | Proxy health check (optional) |
| doctor.sh | Installation verification |
