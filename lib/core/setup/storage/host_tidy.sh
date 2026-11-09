#!/bin/bash
# Deep clean of the SERVER itself (not the VPSs): returns trapped pool space, empties the
# apt download cache, trims system logs and removes old kernels. Runs weekly by cron.
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

  echo "  - removing damaged or half-written backup files"
  clean_stale_temp_backups
  delete_damaged_backups

  remove_old_kernels
  limit_system_journal

  after=$(df -m --output=used / | tail -1 | tr -d ' ')
  echo "Done. Used after: ${after}MB (freed $((before - after))MB)."
}
