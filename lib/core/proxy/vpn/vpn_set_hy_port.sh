#!/bin/bash
# Move a VPS's Hysteria2 to another public UDP port. Devices must import their links again.
#   vpn_set_hy_port <vps> <udp_port>
vpn_set_hy_port() {
  local vps="${1:?vps}" new="${2:?port}" old ip
  [ -n "$(vpn_get_port "$vps")" ] || { echo "ERROR: $vps has no VPN."; return 1; }
  [[ "$new" =~ ^[0-9]+$ ]] && [ "$new" -ge 1 ] && [ "$new" -le 65535 ] || { echo "ERROR: port must be 1-65535."; return 1; }
  old=$(vpn_get_hy_port "$vps")
  [ "$new" = "$old" ] && { echo "Hysteria2 already uses UDP $new."; return 0; }
  if [ -n "$(host_port_owner "$new" udp)" ] \
     || awk -F'|' -v p="$new" '$1 == "udp" && $3 == p { f = 1 } END { exit !f }' "$PORT_FORWARD_RULES_FILE" 2>/dev/null; then
    echo "ERROR: UDP $new is already used on this server."; return 1
  fi
  ip=$(get_ip "$vps")
  [ -n "$ip" ] || { echo "ERROR: $vps has no IP address."; return 1; }
  port_forward_apply_rule udp 0.0.0.0 "$new" "$ip" "$VPN_HY_INNER_PORT" || { echo "ERROR: iptables refused the UDP rule."; return 1; }
  port_forward_append_rule_to_file "$PORT_FORWARD_RULES_FILE" udp 0.0.0.0 "$new" "$ip" "$VPN_HY_INNER_PORT"
  port_forward_delete_rule udp 0.0.0.0 "$old" "$ip" "$VPN_HY_INNER_PORT"
  port_forward_remove_rule_from_file "$PORT_FORWARD_RULES_FILE" udp 0.0.0.0 "$old" "$ip" "$VPN_HY_INNER_PORT"
  incus config set "$vps" user.vpsforge.vpn_hy_port "$new" || return 1
  save_iptables
  vpn_sub_refresh "$vps" >/dev/null 2>&1 || true   # subscriptions give the new port at the next update
  echo "Hysteria2 now uses UDP $new. Open UDP $new in your cloud firewall."
}
