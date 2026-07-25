#!/bin/bash
# install_ponytail.sh — Install ponytail (dev tool)
install_ponytail() {
  pip install ponytail-dev 2>&1
}
verify_ponytail() {
  if command -v ponytail >/dev/null 2>&1; then
    echo "ponytail: $(ponytail --version 2>/dev/null || echo 'installed')"
  fi
}
version_ponytail() {
  ponytail --version 2>/dev/null || echo "unknown"
}