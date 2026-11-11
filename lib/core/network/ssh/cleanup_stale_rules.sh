#!/bin/bash
# Scan and remove port-forwarding rules for VPSs that no longer exist.
cleanup_stale_rules() {
  local line port ip removed=0 inventory
  echo "Scanning VPSForge port-forwarding rules..."
  # One look at Incus. If it does not answer, or a VPS has no known address, nothing is removed.
  inventory=$(vps_inventory 2>/dev/null || true)
  [ -n "$inventory" ] || { echo "Incus did not answer: nothing was removed."; return 1; }
  if awk -F'|' '$2 == "" { f = 1 } END { exit !f }' <<< "$inventory"; then
    echo "A VPS has no known address: nothing was removed."; return 1
  fi

  while read -r line; do
    [ -z "$line" ] && continue
    port=$(echo "$line" | sed -n 's/.*dpt:\([0-9]\+\).*/\1/p')
    ip=$(echo "$line" | sed -n 's/.*to:\([0-9.]\+\):22.*/\1/p')
    [ -z "$port" ] || [ -z "$ip" ] && continue

    # Only manage VPSForge's own SSH port range and current Incus subnet.
    [[ "$port" =~ ^[0-9]+$ ]] || continue
    [ "$port" -ge $((SSH_PORT_BASE + 1)) ] || continue
    [[ "$ip" == "${NETWORK_PREFIX}."* ]] || continue

    local found=0
    awk -F'|' -v ip="$ip" '$2 == ip { f = 1 } END { exit !f }' <<< "$inventory" && found=1

    if [ "$found" -eq 0 ]; then
      echo "Removing stale rule: port $port -> $ip:22"
      remove_port "$port"
      removed=$((removed+1))
    fi
  done < <(iptables -t nat -L PREROUTING -n 2>/dev/null | grep -E "dpt:[0-9]+.*to:${NETWORK_PREFIX}\.[0-9]+:22" || true)

  save_iptables
  echo "Cleanup complete. Removed $removed stale rule(s)."
}
