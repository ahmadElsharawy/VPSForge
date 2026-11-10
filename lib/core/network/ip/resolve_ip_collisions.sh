#!/bin/bash
# Find VPSs that share one internal IP (for example after restoring an old backup) and give the
# extra ones a free address of their own, moving their forwards and SSH port along (change_vps_ip).
# The VPS whose network card really holds the address keeps it; the others move.
# One `incus list` call to find them.
resolve_ip_collisions() {
  local ip names keep name new_ip
  while IFS='|' read -r ip keep names; do
    [ -n "$ip" ] || continue
    for name in $names; do
      [ "$name" = "$keep" ] && continue
      new_ip=$(free_vps_ip) || { echo "WARNING: '$name' shares $ip with '$keep' and no free address is left."; continue; }
      echo "IP conflict: '$name' shares $ip with '$keep'. Moving '$name' to $new_ip..."
      change_vps_ip "$name" "$new_ip" || echo "WARNING: could not move '$name' to $new_ip."
    done
  done < <(incus list --format json 2>/dev/null | python3 -c '
import json, sys
by_ip = {}
for c in json.load(sys.stdin):
    cfg = c.get("config") or {}
    card = ((c.get("expanded_devices") or {}).get("eth0") or {}).get("ipv4.address", "")
    ip = cfg.get("user.vpsforge.ip") or card
    if ip:
        by_ip.setdefault(ip, []).append((c["name"], card == ip))
for ip, owners in by_ip.items():
    if len(owners) < 2:
        continue
    owners.sort(key=lambda o: (not o[1], o[0]))   # the one whose card holds the address first
    print("%s|%s|%s" % (ip, owners[0][0], " ".join(o[0] for o in owners)))
' 2>/dev/null)
}
