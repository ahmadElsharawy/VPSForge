#!/bin/bash
# Deletes all snapshots for a VPS prior to container removal.
_delete_vps_snapshots() {
  local n="$1" snap
  local -a s_list
  mapfile -t s_list < <(incus snapshot list "$n" --format csv 2>/dev/null | cut -d',' -f1 || true)
  for snap in "${s_list[@]}"; do
    [ -n "$snap" ] && incus snapshot delete "$n" "$snap" >/dev/null 2>&1 || true
  done
}
