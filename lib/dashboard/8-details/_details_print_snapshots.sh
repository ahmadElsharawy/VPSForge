#!/bin/bash
# Gathers and displays snapshot history for a VPS container.
_details_print_snapshots() {
  local name="$1" sn
  local -a snapshot_list=()
  local s_name s_date rest
  while IFS=',' read -r s_name s_date rest; do
    [ -n "$s_name" ] || continue
    snapshot_list+=("$s_name ($s_date)")
  done < <(incus snapshot list "$name" --format csv 2>/dev/null || true)

  echo "── Snapshots History (${#snapshot_list[@]}) ──────────────────────────"
  if [ "${#snapshot_list[@]}" -gt 0 ]; then
    for sn in "${snapshot_list[@]}"; do
      echo "  • $sn"
    done
  else
    echo "  None"
  fi
  echo
}
