#!/bin/bash
# VPSForge v1.0.0 — Resource allocation totals.

total_allocated() {
  local t=0 n r
  while read -r n; do
    [ -z "$n" ] && continue
    r=$(ram_mb "$(get_ram "$n")")
    [[ "$r" =~ ^[0-9]+$ ]] && t=$((t+r))
  done < <(incus list -c n --format csv | grep -v '^$' || true)
  echo "$t"
}

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
