#!/bin/bash
cleanup_stale_rules() {
  local line port ip removed=0
  echo "Scanning VPSForge port-forwarding rules..."

  while read -r line; do
    [ -z "$line" ] && continue
    port=$(echo "$line" | sed -n 's/.*dpt:\([0-9]\+\).*/\1/p')
    ip=$(echo "$line" | sed -n 's/.*to:\([0-9.]\+\):22.*/\1/p')
    [ -z "$port" ] || [ -z "$ip" ] && continue

    # Only manage VPSForge's own SSH port range and current Incus subnet.
    [[ "$port" =~ ^[0-9]+$ ]] || continue
    [ "$port" -ge $((SSH_PORT_BASE + 1)) ] || continue
    [[ "$ip" == "${NETWORK_PREFIX}."* ]] || continue

    local found=0 n current_ip
    while read -r n; do
      [ -z "$n" ] && continue
      current_ip=$(get_ip "$n")
      if [ "$current_ip" = "$ip" ]; then found=1; break; fi
    done < <(incus list -c n --format csv 2>/dev/null | grep -v '^$' || true)

    if [ "$found" -eq 0 ]; then
      echo "Removing stale rule: port $port -> $ip:22"
      remove_port "$port"
      removed=$((removed+1))
    fi
  done < <(iptables -t nat -L PREROUTING -n 2>/dev/null | grep -E "dpt:[0-9]+.*to:${NETWORK_PREFIX}\.[0-9]+:22" || true)

  save_iptables
  echo "Cleanup complete. Removed $removed stale rule(s)."
}
