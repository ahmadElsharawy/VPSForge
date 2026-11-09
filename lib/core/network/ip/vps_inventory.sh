#!/bin/bash
# Print one line per VPS: name|ip|ssh_port. It asks Incus ONCE (one json call), so callers
# never need a separate incus call per VPS. The ip is the saved one, else the live eth0 address.
vps_inventory() {
  incus list --format json 2>/dev/null | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)
for inst in data:
    cfg = inst.get("config", {}) or {}
    ip = cfg.get("user.vpsforge.ip", "")
    if not ip:
        net = ((inst.get("state") or {}).get("network") or {}).get("eth0") or {}
        for addr in net.get("addresses", []):
            if addr.get("family") == "inet":
                ip = addr.get("address", "")
                break
    print("%s|%s|%s" % (inst.get("name", ""), ip, cfg.get("user.vpsforge.ssh_port", "")))
'
}
