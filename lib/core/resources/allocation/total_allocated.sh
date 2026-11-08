#!/bin/bash
total_allocated() {
  local t=0 n r
  while read -r n; do
    [ -z "$n" ] && continue
    r=$(ram_mb "$(get_ram "$n")")
    [[ "$r" =~ ^[0-9]+$ ]] && t=$((t+r))
  done < <(incus list -c n --format csv | grep -v '^$' || true)
  echo "$t"
}
