#!/bin/bash
# Disk space (GB) that can be given to <target>: the host's free space after all
# VPS limits, PLUS the target's own current limit (so editing a VPS's disk never counts
# its own old size against itself). While a VPS is being reinstalled its original is kept
# aside as <target>-old-reinstall and is deleted when the new one is ready, so that copy's
# limit is credited too.
get_disk_available_for_vps() {
  local target="${1:-}" available credit=0 limit
  available=$(get_host_disk_available_gb)
  if [ -n "$target" ]; then
    local name
    for name in "$target" "${target}-old-reinstall"; do
      incus info "$name" >/dev/null 2>&1 || continue
      limit=$(get_vps_disk_limit_gb "$name" 2>/dev/null || true)
      [[ "$limit" =~ ^[0-9]+$ ]] && credit=$((credit + limit))
    done
  fi
  echo $((available + credit))
}
