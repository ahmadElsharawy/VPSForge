#!/bin/bash
# Returns current root disk usage in GB (formatted to 1 decimal) for a VPS container.
get_vps_disk_usage_gb() {
  local vps_name="$1" bytes=0
  bytes=$(incus query "/1.0/instances/$vps_name/state" </dev/null 2>/dev/null | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    disk = data.get("disk", {})
    usage = 0
    for dev, info in disk.items():
        if isinstance(info, dict):
            u = info.get("usage", 0)
            if u and int(u) > usage:
                usage = int(u)
    print(usage)
except Exception:
    print(0)
' 2>/dev/null || echo 0)

  if [ -z "$bytes" ] || [ "$bytes" -eq 0 ] 2>/dev/null; then
    bytes=$(incus exec "$vps_name" -- sh -c 'du -s -B1 --exclude=/proc --exclude=/sys --exclude=/dev / 2>/dev/null | awk "{print \$1}"' </dev/null 2>/dev/null || echo 0)
  fi

  [[ "$bytes" =~ ^[0-9]+$ ]] || bytes=0
  awk -v b="$bytes" 'BEGIN {printf "%.1f", b/1073741824}'
}
