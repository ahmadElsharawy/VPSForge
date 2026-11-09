#!/bin/bash
# Print every tunnel of every VPS, one per line:  vps|tunnel_port|my_pc_port|public_port|domain|state
# (a single Incus call, no matter how many VPSs there are)
tunnel_all_records() {
  incus list --format json 2>/dev/null | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)
for inst in data:
    raw = (inst.get("config") or {}).get("user.vpsforge.tunnels", "")
    for rec in raw.split(";"):
        if rec:
            print("%s|%s" % (inst.get("name", ""), rec))
'
}
