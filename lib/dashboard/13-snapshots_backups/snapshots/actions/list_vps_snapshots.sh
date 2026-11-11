#!/bin/bash
# Lists all existing snapshots for a VPS container and stores their names in SNAPSHOT_NAMES_RESULT.
list_vps_snapshots() {
  local name="$1" snap_name date_created rest
  SNAPSHOT_NAMES_RESULT=()
  echo "Snapshots for $name:"
  while IFS=',' read -r snap_name date_created rest; do
    [ -n "$snap_name" ] || continue
    SNAPSHOT_NAMES_RESULT+=("$snap_name")
    printf "   %2d) %-35s (Created: %s)\n" "${#SNAPSHOT_NAMES_RESULT[@]}" "$snap_name" "$date_created"
  done < <(incus snapshot list "$name" --format csv 2>/dev/null || true)

  if [ "${#SNAPSHOT_NAMES_RESULT[@]}" -eq 0 ]; then
    echo "  No snapshots found for $name."
    return 1
  fi
  return 0
}
