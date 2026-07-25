#!/bin/bash
# install_caveman.sh — Install caveman
install_caveman() {
  ctx plugins add --package @badloop/ctx-caveman 2>&1
}
verify_caveman() {
  ctx plugins list 2>&1 | grep -q caveman && echo "caveman installed"
}
version_caveman() {
  echo "caveman plugin"
}