#!/bin/bash
# Remove half-written export files and Incus's temporary backups, but never while an export is running.
clean_stale_temp_backups() {
  pgrep -x incus -a 2>/dev/null | grep -q ' export ' && return 0
  local tmp_dir="/opt/vpsforge-backups/.tmp"
  if [ -d "$tmp_dir" ]; then
    local f
    for f in "$tmp_dir"/*; do
      [ -f "$f" ] || continue
      # a file touched in the last 10 minutes may be a finished export that another session is about to move
      if [ -n "$(find "$f" -mmin +10 2>/dev/null)" ] && ! fuser "$f" >/dev/null 2>&1; then
        rm -f "$f"
      fi
    done
  fi

  # Clean internal Incus orphaned backups (a slow per-VPS check: at most once every 10 minutes)
  local stamp="/run/vpsforge-temp-backups.stamp"
  if [ -f "$stamp" ] && [ -z "$(find "$stamp" -mmin +10 2>/dev/null)" ]; then
    return 0
  fi
  touch "$stamp" 2>/dev/null || true
  local inst_list inst backup_list b_name
  inst_list=$(incus list -c n --format csv 2>/dev/null | grep -v '^$' || true)
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
    for b_name in $backup_list; do
      [ -n "$b_name" ] || continue
      incus query -X DELETE "/1.0/instances/${inst}/backups/${b_name}" >/dev/null 2>&1 || true
    done
  done
}
