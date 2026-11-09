#!/bin/bash
# Print the name of the VPS that owns an IP (one Incus call in total).
get_vps_name_by_ip() {
  local target_ip="$1" n ip port
  [ -z "$target_ip" ] && return 1
  while IFS='|' read -r n ip port; do
    if [ -n "$n" ] && [ "$ip" = "$target_ip" ]; then
      echo "$n"
      return 0
    fi
  done < <(vps_inventory)
  return 1
}
