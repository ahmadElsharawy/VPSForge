#!/bin/bash
# Close the public side of a tunnel (the record stays, so it can be started again).
# Only this tunnel's domain or port is touched; the VPS's other routes and forwards stay.
#   tunnel_public_stop <vps> <tunnel_port> <public_port|""> <domain|"">
tunnel_public_stop() {
  local vps="${1:?vps}" tport="${2:?tunnel port}" ext="${3:-}" domain="${4:-}" ip
  ip=$(get_ip "$vps")

  if [ -n "$domain" ]; then
    caddy_unlink_domain "$CADDY_CONF_DIR/${vps}.caddy" "$domain"
    systemctl reload-or-restart caddy >/dev/null 2>&1 || true
    remove_domain_from_guest_hosts "$vps" "$domain" 2>/dev/null || true
    sync_vps_metadata "$vps"
    return 0
  fi

  [ -n "$ip" ] && [ -n "$ext" ] || return 0
  port_forward_delete_rule tcp 0.0.0.0 "$ext" "$ip" "$tport"
  port_forward_remove_rule_from_file "$PORT_FORWARD_RULES_FILE" tcp 0.0.0.0 "$ext" "$ip" "$tport"
  save_iptables
  sync_vps_metadata "$vps"
}
