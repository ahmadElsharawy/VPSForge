#!/bin/bash
# Returns current RAM usage in MB for a VPS container.
get_vps_ram_usage_mb() {
  local vps_name="$1" bytes
  bytes=$(incus query "/1.0/instances/$vps_name/state" 2>/dev/null |
    python3 -c 'import sys,json; print(json.load(sys.stdin).get("memory",{}).get("usage",0))' 2>/dev/null || echo 0)
  [[ "$bytes" =~ ^[0-9]+$ ]] || bytes=0
  echo $((bytes / 1024 / 1024))
}
