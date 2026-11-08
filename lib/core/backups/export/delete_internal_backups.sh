#!/bin/bash
# Delete Incus's internal temporary backups of <vps_name>. VPSForge never keeps them (it exports
# straight to a file), so any that exist are leftovers of an interrupted export and would block or
# bloat the next one.
#   delete_internal_backups <vps_name>
delete_internal_backups() {
  local name="${1:?vps}" item
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
  return 0
}
