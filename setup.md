# Do It — Setup Manifest

Everything `doit` depends on. Copy this to replicate the full environment.

## Global Tools

### RTK (Rust Token Killer)
Token-optimized CLI proxy. 60-90% savings on dev operations. [GitHub](https://github.com/rtk-ai/rtk)

```bash
# Install (binary goes to $HOME/.local/bin)
curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh

# Ensure $HOME/.local/bin is in PATH (install script doesn't do this)
export PATH="$HOME/.local/bin:$PATH"
# Persist for future shells:
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# Initialize for Claude Code
rtk init -g

# Verify
rtk --version       # should show rtk X.Y.Z
rtk gain            # should work
```

**Note:** The install script only downloads the binary to `$HOME/.local/bin/rtk`. It does NOT add this directory to PATH or run `rtk init -g`. Both steps are required for Claude Code integration. `setup.sh` handles this automatically.

### Rust (required by TokenSave)
Systems programming language. Required for building TokenSave from source. [Rust](https://www.rust-lang.org)

```bash
# Install via rustup (Tsinghua mirror for China)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
  | RUSTUP_DIST_SERVER=https://mirrors.tuna.tsinghua.edu.cn/rustup \
    RUSTUP_UPDATE_ROOT=https://mirrors.tuna.tsinghua.edu.cn/rustup/rustup \
    sh -s -- -y

# Configure cargo mirror (USTC)
mkdir -p ~/.cargo
cat > ~/.cargo/config.toml <<'EOF'
[source.crates-io]
replace-with = 'ustc'
[source.ustc]
registry = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"
EOF

# Verify
rustc --version
cargo --version
```

### TokenSave
MCP server for code intelligence. 40+ tools, 30+ languages. Pre-indexed semantic knowledge graphs for instant code understanding. [GitHub](https://github.com/aovestdipaperino/tokensave)

```bash
# Install (requires Rust)
cargo install tokensave

# Configure for Claude Code
tokensave install --agent claude

# Initialize in project
tokensave init

# Verify
tokensave status
```

## Context-Mode Plugin

Context window management plugin. Keeps raw data in sandbox, auto-indexes output, provides semantic search. **Must be installed as a Claude Code plugin.** [GitHub](https://github.com/mksglu/context-mode)

```bash
# Install (Claude Code v1.0.33+)
claude plugin marketplace add mksglu/context-mode
claude plugin install context-mode@context-mode

# Verify
/context-mode:ctx-doctor
```

**Key features:**
- `ctx_batch_execute` — run multiple commands, auto-index, search (replaces many Read/Grep calls)
- `ctx_execute_file` — process large files without loading into context
- `ctx_fetch_and_index` — fetch and index web content
- `ctx_search` — semantic search across indexed content

## Headroom (Context Optimization)

Proxy compression + memory persistence for token optimization. [GitHub](https://github.com/nicholasgriffintn/headroom)

```bash
# Install via uv tool
uv tool install "headroom-ai[mcp,proxy]"

# Register MCP server
headroom mcp install

# Verify
headroom --version
claude mcp list | grep headroom
```

**Optional proxy mode** (continuous token optimization):
```bash
# Start proxy
headroom proxy

# Use with Claude Code
ANTHROPIC_BASE_URL=http://127.0.0.1:8787 claude
```

## lean-ctx (Context Optimization)

Lean context window management with AI agent integration. [Website](https://leanctx.com)

```bash
# 1. Install binary
curl -fsSL https://leanctx.com/install.sh | sh

# 2. Verify
lean-ctx --version

# 3. Connect all AI tools
lean-ctx onboard
source ~/.bashrc
lean-ctx init --agent claude

# 4. Manual fallback (if step 3 doesn't configure Claude Code)
claude mcp add lean-ctx lean-ctx

# 5. Verify
lean-ctx doctor
```

After installation, usage rules appear at `~/.claude/rules/lean-ctx.md`.

## Tavily MCP (Internet Search)

Remote MCP. Streamable HTTP transport — no install needed.

```jsonc
// Add to project .mcp.json (replace with your API key):
"tavily": {
  "url": "https://mcp.tavily.com/mcp/?tavilyApiKey=<your-api-key>",
  "type": "streamable-http"
}
```

## Skills Dependency Model

doit uses a **bundled dependency model**. Core skills ship inside `skills/` and are installed automatically. Optional skills require separate installation.

### Bundled Skills (ship with doit)

| Skill | Purpose | Used In |
|-------|---------|---------|
| `grill-me` | Idea grilling | Phase 1 |
| `tdd` | TDD loop | Phase 3 |
| `diagnose` | Bug diagnosis | Phase 0 (type B) |
| `prototype` | Throwaway prototypes | Phase 1 |
| `handoff` | Session handoff | Any phase |
| `improve-codebase-architecture` | Architecture deepening | Phase 5 |

### External Tools (user installs)

| Tool | Install | Used In |
|------|---------|---------|
| Context-Mode | `claude plugin marketplace add mksglu/context-mode` | Phase 1-6 |
| RTK | `curl ... \| sh` + `rtk init -g` (see above) | All phases (auto-wrap) |
| uv | `pip install uv` | Phase 3 |
| Rust | `curl ... \| rustup ...` (see above) | Prerequisite for TokenSave |
| TokenSave | `cargo install tokensave && tokensave install --agent claude` | Phase 2, 3, 5, 6 |
| Headroom | `uv tool install "headroom-ai[mcp,proxy]"` + `headroom mcp install` | Phase 10 |
| lean-ctx | `curl ... \| sh` + `lean-ctx onboard` + `lean-ctx init --agent claude` | All phases |
| MemPalace | `claude plugin marketplace add MemPalace/mempalace` | Phase 0, 1, 3, 5, 8, 9.5, 10 |
| caveman | `claude plugin marketplace add JuliusBrussee/caveman && claude plugin install caveman@caveman` (curl fallback) | Phase 0+ |
| code-review | `claude plugin install code-review` | Phase 5 |
| Tavily MCP | Remote, API key only | Phase 1 |

### Adding Dependencies

```bash
# Add a bundled skill
./scripts/add-dependency.sh <skill-name> bundled

# Add an optional skill (edit package.json)
"dependencies.optionalSkills": {
  "new-skill": "recommended"
}

# Add an external tool (edit package.json)
"dependencies.tools": {
  "new-tool": "install-command"
}
```

## Settings

### Global (~/.claude/settings.json)

```jsonc
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "<your-token>",
    "ANTHROPIC_BASE_URL": "<your-proxy-url>",
    "model": "<your-model>"
  },
  "permissions": {
    "defaultMode": "bypassPermissions"
  },
  "skipDangerousModePermissionPrompt": true,
  "theme": "dark",
  "language": "中文",
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{"type": "command", "command": "rtk hook claude"}]
    }]
  }
}
```

### Project (~/.claude/settings.json in repo)

TokenSave auto-indexes after edits — no PostToolUse hook needed.
