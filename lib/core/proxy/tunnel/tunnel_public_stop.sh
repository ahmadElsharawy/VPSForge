#!/bin/bash
# Close the public side of a tunnel (the record stays, so it can be started again).
# Only this tunnel's domain or port is touched; the VPS's other routes and forwards stay.
#   tunnel_public_stop <vps> <tunnel_port> <public_port|""> <domain|"">
tunnel_public_stop() {
  local vps="${1:?vps}" tport="${2:?tunnel port}" ext="${3:-}" domain="${4:-}" ip line
  ip=$(get_ip "$vps")

  if [ -n "$domain" ]; then
    line=$(list_proxy_routes 2>/dev/null | awk -F'|' -v v="$vps" -v d="$domain" -v p=":$tport"       '$1 == v && $2 == d && $3 == "/" && substr($4, length($4) - length(p) + 1) == p { print $5; exit }')
    [ -n "$line" ] && delete_proxy_route "$vps" "$line"
    return 0
  fi

  [ -n "$ip" ] && [ -n "$ext" ] || return 0
  port_forward_delete_rule tcp 0.0.0.0 "$ext" "$ip" "$tport"
  port_forward_remove_rule_from_file "$PORT_FORWARD_RULES_FILE" tcp 0.0.0.0 "$ext" "$ip" "$tport"
  save_iptables
  sync_vps_metadata "$vps"
}
