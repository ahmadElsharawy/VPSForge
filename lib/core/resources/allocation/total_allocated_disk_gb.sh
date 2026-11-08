#!/bin/bash
# Sum of all disk limits set on existing VPS containers (in GB).
total_allocated_disk_gb() {
  local t=0 n d
  while read -r n; do
    [ -z "$n" ] && continue
    d=$(get_vps_disk_limit_gb "$n" 2>/dev/null || true)
    [[ "$d" =~ ^[0-9]+$ ]] && t=$((t+d))
  done < <(incus list -c n --format csv | grep -v '^$' || true)
  echo "$t"
}
