#!/bin/bash
# install_headroom.sh — Install headroom
install_headroom() {
  ctx plugins add --package @badloop/ctx-headroom 2>&1
}
verify_headroom() {
  command -v ctx_headroom_compress || ctx plugins list 2>&1 | grep -q headroom
}
version_headroom() {
  echo "headroom plugin"
}