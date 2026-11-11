#!/bin/bash
# Sum of all disk limits set on existing VPS containers (in GB).
total_allocated_disk_gb() {
  local total_disk_gb=0 vps_name disk_limit
  while read -r vps_name; do
    [ -z "$vps_name" ] && continue
    disk_limit=$(get_vps_disk_limit_gb "$vps_name" 2>/dev/null || true)
    [[ "$disk_limit" =~ ^[0-9]+$ ]] && total_disk_gb=$((total_disk_gb + disk_limit))
  done < <(incus list -c n --format csv | grep -v '^$' || true)
  echo "$total_disk_gb"
}
