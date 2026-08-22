#!/bin/bash

delete_vps_snapshot() {
  local name="${1:-}" snap_name="${2:-}"
  [ -z "$snap_name" ] && { echo "No snapshot specified."; return 1; }

  # Resolve numeric index if passed directly
  if [[ "$snap_name" =~ ^[0-9]+$ ]]; then
    local -a snaps=()
    mapfile -t snaps < <(incus snapshot list "$name" --format csv 2>/dev/null | cut -d',' -f1 || true)
    if [ "$snap_name" -ge 1 ] && [ "$snap_name" -le "${#snaps[@]}" ]; then
      snap_name="${snaps[$((snap_name-1))]}"
    fi
  fi

  echo "Deleting snapshot '$snap_name' from $name..."
  incus snapshot delete "$name" "$snap_name" && echo "Snapshot '$snap_name' deleted."
}
