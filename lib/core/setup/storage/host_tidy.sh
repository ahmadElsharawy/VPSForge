#!/bin/bash
# Optional deep clean of the SERVER itself (not the VPSs): returns trapped pool
# space, empties the apt download cache, and trims huge system logs.
#   vpsforge tidy
host_tidy() {
  local before after
  before=$(df -m --output=used / | tail -1 | tr -d ' ')
  echo "Tidying the server (used before: ${before}MB)..."

  echo "  - returning freed VPS pool space to the disk"
  reclaim_pool_space

  echo "  - emptying the apt package cache"
  apt-get clean >/dev/null 2>&1 || true

  if command -v journalctl >/dev/null 2>&1; then
    echo "  - trimming system logs to 200MB"
    journalctl --vacuum-size=200M >/dev/null 2>&1 || true
  fi

  after=$(df -m --output=used / | tail -1 | tr -d ' ')
  echo "Done. Used after: ${after}MB (freed $((before - after))MB)."
}
