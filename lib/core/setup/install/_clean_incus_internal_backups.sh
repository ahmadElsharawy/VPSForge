#!/bin/bash
# Purge orphaned internal Incus container backups at most once every 10 minutes.
_clean_incus_internal_backups() {
  local stamp="/run/vpsforge-temp-backups.stamp"
  if [ -f "$stamp" ] && [ -z "$(find "$stamp" -mmin +10 2>/dev/null)" ]; then
    return 0
  fi
  touch "$stamp" 2>/dev/null || true

  local inst_list inst backup_list backup_name
  # Only VPSForge's own VPSs (they carry user.vpsforge.num): other containers' backups are not ours to delete.
  inst_list=$(incus list --format json 2>/dev/null | python3 -c '
import sys, json
try:
    for inst in json.load(sys.stdin):
        if (inst.get("config") or {}).get("user.vpsforge.num"):
            print(inst.get("name", ""))
except Exception:
    pass
' 2>/dev/null || true)
  for inst in $inst_list; do
    backup_list=$(incus query "/1.0/instances/${inst}/backups" 2>/dev/null | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    if isinstance(data, dict):
        data = data.get("metadata", [])
    if isinstance(data, list):
        for path in data:
            print(path.split("/").pop())
except Exception:
    pass
' 2>/dev/null || true)
    for backup_name in $backup_list; do
      [ -n "$backup_name" ] || continue
      incus query -X DELETE "/1.0/instances/${inst}/backups/${backup_name}" >/dev/null 2>&1 || true
    done
  done
}
