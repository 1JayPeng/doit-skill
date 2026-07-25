#!/bin/bash
# install_mempalace.sh — Install mempalace
install_mempalace() {
  ctx plugins add --package @badloop/ctx-mempalace 2>&1
}
verify_mempalace() {
  command -v ctx_mempalace_status || ctx plugins list 2>&1 | grep -q mempalace
}
version_mempalace() {
  echo "mempalace plugin"
}