#!/bin/bash
# install_codegraph.sh — Install CodeGraph
install_codegraph() {
  local workspace="${WORKSPACE:-$SCRIPT_DIR}"
  local addon_path="$SCRIPT_DIR/addons/codegraph"
  
  if [ -f "$addon_path/install.sh" ]; then
    bash "$addon_path/install.sh" "$workspace" 2>&1
  fi
}
verify_codegraph() {
  if command -v codegraph >/dev/null 2>&1 || [ -d "$HOME/.codegraph/" ]; then
    echo "CodeGraph installed"
  fi
}
version_codegraph() {
  codegraph --version 2>/dev/null || echo "unknown"
}