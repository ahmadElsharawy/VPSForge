#!/bin/bash
# Find VPSs that share one internal IP (for example after restoring an old backup) and give the
# extra ones a free address of their own, moving their forwards and SSH port along (change_vps_ip).
# The VPS whose network card really holds the address keeps it; the others move.
# One `incus list` call to find them.
resolve_ip_collisions() {
  local ip names keep name new_ip num_name port_name
  while IFS='|' read -r ip keep names; do
    [ -n "$ip" ] || continue
    for name in $names; do
      [ "$name" = "$keep" ] && continue
      new_ip=$(free_vps_ip) || { echo "WARNING: '$name' shares $ip with '$keep' and no free address is left."; continue; }
      echo "IP conflict: '$name' shares $ip with '$keep'. Moving '$name' to $new_ip..."
      num_name=$(get_num "$name")
      port_name=$(get_vps_saved_port "$name" 2>/dev/null || true)
      [[ "$port_name" =~ ^[0-9]+$ ]] || port_name=$(vps_fixed_port "$num_name")

      _set_vps_ip_safe "$name" "$new_ip" || { echo "WARNING: could not set IP on '$name'."; continue; }
      incus config set "$name" user.vpsforge.ip "$new_ip" 2>/dev/null || true

      if is_vps_running "$name"; then
        apply_guest_static_network "$name" "$new_ip" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}" || true
        configure_guest_dns "$name" || true
      fi

      [ -n "$port_name" ] && set_vps_saved_port "$name" "$port_name"
      [ -n "$port_name" ] && vps_ssh_forward_enabled "$name" && add_forward_rule "$new_ip" "$port_name"
      update_vps_proxy_ip "$name" "$new_ip"
      sync_vps_metadata "$name"
      echo "Moved '$name' to $new_ip (SSH port $port_name)."
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
