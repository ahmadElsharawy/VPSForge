#!/bin/bash
# Add NAT PREROUTING and FORWARD rules to expose a VPS's SSH port on the host.
#   add_forward_rule <ip> <port>
add_forward_rule() {
  local ip="$1" port="$2"
  remove_port "$port"
  remove_ip "$ip"
  iptables -t nat -A PREROUTING -p tcp ! -i incusbr0 --dport "$port" -j DNAT --to-destination "${ip}:22"
  # only traffic that comes from outside the bridge: a VPS must not reach another VPS's ssh port directly
  iptables -C FORWARD ! -i incusbr0 -p tcp -d "$ip" --dport 22 -j ACCEPT 2>/dev/null || \
    iptables -I FORWARD 1 ! -i incusbr0 -p tcp -d "$ip" --dport 22 -j ACCEPT
  while iptables -D FORWARD -p tcp -d "$ip" --dport 22 -j ACCEPT 2>/dev/null; do :; done   # the old rule without the restriction
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
