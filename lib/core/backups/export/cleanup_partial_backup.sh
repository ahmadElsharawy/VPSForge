#!/bin/bash
# After a backup/export that failed or was stopped: delete the half-written file
# and Incus's internal temporary copy, then give the space back to the disk.
#   cleanup_partial_backup <vps_name> <temp_file> [reason]
cleanup_partial_backup() {
  local name="${1:?vps}" tmp_file="${2:?temp file}" reason="${3:-}" item
  rm -f "$tmp_file"

  while read -r item; do
    [ -n "$item" ] || continue
    incus query -X DELETE "/1.0/instances/${name}/backups/${item}" >/dev/null 2>&1 || true
  done < <(incus query "/1.0/instances/${name}/backups" 2>/dev/null | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    for path in (data.get("metadata", []) if isinstance(data, dict) else data):
        print(path.split("/").pop())
except Exception:
    pass
' 2>/dev/null)

  reclaim_pool_space
  [ -n "$reason" ] && echo "   (no backup was saved: $reason)"
  return 0
}
