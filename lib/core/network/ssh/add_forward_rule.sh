#!/bin/bash
add_forward_rule() {
  local ip="$1" port="$2"
  remove_port "$port"
  remove_ip "$ip"
  iptables -t nat -A PREROUTING -p tcp ! -i incusbr0 --dport "$port" -j DNAT --to-destination "${ip}:22"
  iptables -C FORWARD -p tcp -d "$ip" --dport 22 -j ACCEPT 2>/dev/null || \
    iptables -I FORWARD 1 -p tcp -d "$ip" --dport 22 -j ACCEPT
  save_iptables

  mkdir -p "$(dirname "$PORT_FORWARD_RULES_FILE")" 2>/dev/null || true
  touch "$PORT_FORWARD_RULES_FILE" 2>/dev/null || true
  if ! grep -q "tcp|0.0.0.0|${port}|${ip}|22" "$PORT_FORWARD_RULES_FILE" 2>/dev/null; then
    echo "tcp|0.0.0.0|${port}|${ip}|22" >> "$PORT_FORWARD_RULES_FILE"
  fi
  local name
  name=$(get_vps_name_by_ip "$ip" 2>/dev/null || true)
  [ -n "$name" ] && sync_vps_metadata "$name"
}
