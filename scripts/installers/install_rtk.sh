#!/bin/bash
# install_rtk.sh — Install RTK (Rust Token Killer)
install_rtk() {
  local rt
  if [ -n "$RTK_INSTALL" ] && [ -f "$RTK_INSTALL" ]; then
    rt=$(curl -fsSL "$RTK_INSTALL" 2>/dev/null | sh 2>&1)
  else
    # Fallback: use direct URL
    rt=$(curl -fsSL https://raw.githubusercontent.com/badloop/rtk/main/install.sh | sh 2>&1)
  fi
  echo "$rt"
  ln -sf "$HOME/.rtk/bin/rtk" "$HOME/.local/bin/rtk" 2>/dev/null || true
}
verify_rtk() {
  command -v rtk && rtk --version 2>&1
}
version_rtk() {
  rtk --version 2>&1 | head -1
}