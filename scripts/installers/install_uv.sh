#!/bin/bash
# install_uv.sh — Install uv (Python package manager)
install_uv() {
  curl -LsSf https://astral.sh/uv/install.sh | sh 2>&1
}
verify_uv() {
  command -v uv && uv --version 2>&1
}
version_uv() {
  uv --version 2>&1
}