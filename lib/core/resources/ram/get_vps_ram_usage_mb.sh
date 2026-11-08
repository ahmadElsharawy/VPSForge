#!/bin/bash
get_vps_ram_usage_mb() {
  local bytes
  bytes=$(incus query "/1.0/instances/$1/state" 2>/dev/null |
    python3 -c 'import sys,json; print(json.load(sys.stdin).get("memory",{}).get("usage",0))' 2>/dev/null || echo 0)
  [[ "$bytes" =~ ^[0-9]+$ ]] || bytes=0
  echo $((bytes / 1024 / 1024))
}
