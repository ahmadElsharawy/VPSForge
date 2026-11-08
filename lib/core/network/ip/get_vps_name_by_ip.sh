#!/bin/bash
get_vps_name_by_ip() {
  local target_ip="$1" n ip
  [ -z "$target_ip" ] && return 1
  while read -r n; do
    [ -z "$n" ] && continue
    ip=$(get_ip "$n" 2>/dev/null || true)
    if [ "$ip" = "$target_ip" ]; then
      echo "$n"
      return 0
    fi
  done < <(incus list -c n --format csv 2>/dev/null | grep -v '^$' || true)
  return 1
}
