#!/bin/bash
# After a snapshot that failed or was stopped: make sure no snapshot with that name remains.
#   cleanup_partial_snapshot <vps_name> <snapshot_name> [reason]
cleanup_partial_snapshot() {
  local name="${1:?vps}" snap="${2:?snapshot}" reason="${3:-}"
  incus snapshot delete "$name" "$snap" >/dev/null 2>&1 || true
  reclaim_pool_space
  [ -n "$reason" ] && echo "   (no snapshot was kept: $reason)"
  return 0
}
