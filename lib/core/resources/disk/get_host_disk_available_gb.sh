#!/bin/bash
# Disk space (GB) still free for new VPS limits: the real free space of the pool's disk, minus
# the part of each VPS's disk limit it has NOT used yet (that part is promised to it).
# What a VPS already wrote is gone from the free space already, so it is not taken off twice.
# One `incus list` call for all VPSs.
get_host_disk_available_gb() {
  local path raw_avail unused net
  path=$(get_incus_pool_path)
  raw_avail=$(df -BG --output=avail "$path" 2>/dev/null | tail -1 | tr -dc '0-9')
  [[ "$raw_avail" =~ ^[0-9]+$ ]] || raw_avail=0
  unused=$(incus list --format json 2>/dev/null | python3 -c '
import json, re, sys
units = {"": 1, "B": 1, "KB": 1e3, "MB": 1e6, "GB": 1e9, "TB": 1e12, "KIB": 2**10, "MIB": 2**20, "GIB": 2**30, "TIB": 2**40}
def size(v):
    m = re.match(r"^\s*([0-9.]+)\s*([A-Za-z]*)\s*$", str(v or ""))
    return float(m.group(1)) * units.get(m.group(2).upper(), 1) if m else 0
total = 0
for c in json.load(sys.stdin):
    limit = size(((c.get("expanded_devices") or {}).get("root") or {}).get("size"))
    if limit <= 0:
        continue
    used = ((((c.get("state") or {}).get("disk") or {}).get("root") or {}).get("usage")) or 0
    total += max(0, limit - used)
print(int(total // 2**30))
' 2>/dev/null)
  [[ "$unused" =~ ^[0-9]+$ ]] || unused=$(total_allocated_disk_gb 2>/dev/null || echo 0)
  net=$(( raw_avail - unused ))
  [ "$net" -lt 0 ] && net=0
  echo "$net"
}
