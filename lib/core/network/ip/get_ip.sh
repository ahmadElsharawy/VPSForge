#!/bin/bash
get_ip() {
  local ip
  ip=$(incus config get "$1" user.vpsforge.ip 2>/dev/null || true)
  if [ -n "$ip" ]; then
    echo "$ip"
    return
  fi

  incus query "/1.0/instances/$1/state" 2>/dev/null | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    network = data.get("network", {})
    eth0 = network.get("eth0", {})
    for addr in eth0.get("addresses", []):
        if addr.get("family") == "inet":
            print(addr.get("address"))
            break
except Exception:
    pass
'
}
