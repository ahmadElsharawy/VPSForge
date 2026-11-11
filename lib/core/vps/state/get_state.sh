#!/bin/bash
# Get the current uppercase status of a VPS (e.g., RUNNING, STOPPED).
get_state() {
  local target="${1:-}" status
  status=$(incus query "/1.0/instances/$target/state" 2>/dev/null |
    python3 -c 'import sys,json; print(json.load(sys.stdin).get("status","").upper())' 2>/dev/null || true)
  if [ -z "$status" ]; then
    status=$(incus list -c ns --format csv 2>/dev/null | awk -F',' -v target="$target" '$1==target {print toupper($2)}')
  fi
  echo "$status"
}
