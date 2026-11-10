#!/bin/bash
# Remove the VPN of a VPS completely: Xray and its files inside it, and the port on this server.
# Safe to repeat, and safe on a stopped VPS (only the server side is removed then).
#   vpn_remove <vps>
vpn_remove() {
  local vps="${1:?vps}" ext ip
  ext=$(vpn_get_port "$vps")
  ip=$(get_ip "$vps" 2>/dev/null || true)
  if [ -n "$ext" ]; then
    [ -n "$ip" ] || ip=$(awk -F'|' -v p="$ext" '$1 == "tcp" && $3 == p && $5 == p { print $4; exit }' "$PORT_FORWARD_RULES_FILE" 2>/dev/null)
    if [ -n "$ip" ]; then
      port_forward_delete_rule tcp 0.0.0.0 "$ext" "$ip" "$ext"
      port_forward_remove_rule_from_file "$PORT_FORWARD_RULES_FILE" tcp 0.0.0.0 "$ext" "$ip" "$ext"
      save_iptables
    fi
  fi
  if is_vps_running "$vps"; then
    incus exec "$vps" --env D="$VPN_GUEST_DIR" -- sh -c '
      systemctl disable --now vpsforge-vpn >/dev/null 2>&1 || true
      rc-service vpsforge-vpn stop >/dev/null 2>&1 || true
      rc-update del vpsforge-vpn default >/dev/null 2>&1 || true
      pkill -x xray >/dev/null 2>&1 || true
      rm -f /etc/systemd/system/vpsforge-vpn.service /etc/init.d/vpsforge-vpn /usr/local/bin/xray
      systemctl daemon-reload >/dev/null 2>&1 || true
      rm -rf "$D"
    ' </dev/null >/dev/null 2>&1 || true
  fi
  incus config unset "$vps" user.vpsforge.vpn >/dev/null 2>&1 || true
  sync_vps_metadata "$vps" >/dev/null 2>&1 || true
  return 0
}
