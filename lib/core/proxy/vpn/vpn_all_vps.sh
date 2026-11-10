#!/bin/bash
# Print every VPS that has a VPN, one per line:  vps|public_tcp_port
# One `incus list` call for all VPSs (cheap on weak hosts).
vpn_all_vps() {
  incus list --format json 2>/dev/null | python3 -c '
import json, sys
for c in json.load(sys.stdin):
    port = (c.get("config") or {}).get("user.vpsforge.vpn", "")
    if port:
        print(c["name"] + "|" + port)
' 2>/dev/null || true
}
