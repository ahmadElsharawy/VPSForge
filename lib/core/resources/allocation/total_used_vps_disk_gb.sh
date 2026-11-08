#!/bin/bash
# Sum of actual disk space used by all VPS containers (in GB).
total_used_vps_disk_gb() {
  local n u
  local -a usages=()
  while read -r n; do
    [ -n "$n" ] || continue
    u=$(get_vps_disk_usage_gb "$n" 2>/dev/null || echo "0")
    usages+=("$u")
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
