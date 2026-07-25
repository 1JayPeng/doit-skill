#!/bin/bash
# install_context_mode.sh — Install context-mode
install_context_mode() {
  npm i -g context-mode@latest 2>&1
  ctx_doctor 2>&1
}
verify_context_mode() {
  command -v ctx_doctor && ctx_doctor --version 2>&1
}
version_context_mode() {
  ctx_doctor --version 2>&1
}