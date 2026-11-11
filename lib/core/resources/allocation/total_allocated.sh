#!/bin/bash
# Sum of all RAM limits set on existing VPS containers (in MB).
total_allocated() {
  local total_mb=0 vps_name ram_val
  while read -r vps_name; do
    [ -z "$vps_name" ] && continue
    ram_val=$(ram_mb "$(get_ram "$vps_name")")
    [[ "$ram_val" =~ ^[0-9]+$ ]] && total_mb=$((total_mb + ram_val))
  done < <(incus list -c n --format csv | grep -v '^$' || true)
  echo "$total_mb"
}
