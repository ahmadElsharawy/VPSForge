#!/bin/bash
# Returns the next available VPS number (highest existing + 1).
next_num() {
  local highest=0 name num
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    num=$(get_num "$name" 2>/dev/null || true)
    if [[ "$num" =~ ^[0-9]+$ ]] && (( num > highest )); then
      highest="$num"
    fi
  done < <(incus list -c n --format csv 2>/dev/null || true)
  echo $((highest + 1))
}
