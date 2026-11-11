#!/bin/bash
# Sum of actual disk space used by all VPS containers (in GB).
total_used_vps_disk_gb() {
  local vps_name usage_val
  local -a usages=()
  while read -r vps_name; do
    [ -n "$vps_name" ] || continue
    usage_val=$(get_vps_disk_usage_gb "$vps_name" 2>/dev/null || echo "0")
    usages+=("$usage_val")
  done < <(incus list -c n --format csv 2>/dev/null | grep -v '^$' || true)

  [ "${#usages[@]}" -gt 0 ] || { echo "0.0"; return; }

  python3 -c "
import sys
try:
    print(f'{sum(float(x) for x in sys.argv[1:]):.1f}')
except Exception:
    print('0.0')
" "${usages[@]}" 2>/dev/null || echo "0.0"
}
