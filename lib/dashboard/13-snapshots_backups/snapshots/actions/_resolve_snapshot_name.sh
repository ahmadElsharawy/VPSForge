#!/bin/bash
# Resolves a numeric index or snapshot name to the actual snapshot name.
_resolve_snapshot_name() {
  local name="${1:-}" snap_name="${2:-}"
  if [[ "$snap_name" =~ ^[0-9]+$ ]] && ! incus snapshot list "$name" --format csv 2>/dev/null | cut -d, -f1 | grep -Fxq "$snap_name"; then
    local -a snaps=()
    mapfile -t snaps < <(incus snapshot list "$name" --format csv 2>/dev/null | cut -d',' -f1 || true)
    if [ "$snap_name" -ge 1 ] && [ "$snap_name" -le "${#snaps[@]}" ]; then
      echo "${snaps[$((snap_name-1))]}"
      return 0
    fi
  fi
  echo "$snap_name"
}
