#!/bin/bash

SNAPSHOT_NAMES_RESULT=()
SELECTED_SNAPSHOT=""

list_vps_snapshots() {
  local name="$1" s date_created
  SNAPSHOT_NAMES_RESULT=()
  echo "Snapshots for $name:"
  while IFS=',' read -r s date_created rest; do
    [ -n "$s" ] || continue
    SNAPSHOT_NAMES_RESULT+=("$s")
    printf "   %2d) %-35s (Created: %s)\n" "${#SNAPSHOT_NAMES_RESULT[@]}" "$s" "$date_created"
  done < <(incus snapshot list "$name" --format csv 2>/dev/null || true)

  if [ "${#SNAPSHOT_NAMES_RESULT[@]}" -eq 0 ]; then
    echo "  No snapshots found for $name."
    return 1
  fi
  return 0
}
