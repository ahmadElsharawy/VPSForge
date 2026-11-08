#!/bin/bash
# After a backup/export that failed or was stopped: delete the half-written file
# and Incus's internal temporary copy, then give the space back to the disk.
#   cleanup_partial_backup <vps_name> <temp_file> [reason]
cleanup_partial_backup() {
  local name="${1:?vps}" tmp_file="${2:?temp file}" reason="${3:-}"
  rm -f "$tmp_file"
  delete_internal_backups "$name"
  reclaim_pool_space
  [ -n "$reason" ] && echo "   (no backup was saved: $reason)"
  return 0
}
