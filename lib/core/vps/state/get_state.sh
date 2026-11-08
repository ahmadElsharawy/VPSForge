#!/bin/bash
get_state() {
  local s
  s=$(incus query "/1.0/instances/$1/state" 2>/dev/null |
    python3 -c 'import sys,json; print(json.load(sys.stdin).get("status","").upper())' 2>/dev/null || true)
  if [ -z "$s" ]; then
    s=$(incus list -c ns --format csv 2>/dev/null | awk -F',' -v target="$1" '$1==target {print toupper($2)}')
  fi
  echo "$s"
}
