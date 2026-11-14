#!/bin/bash
# Remove the VPN of a VPS completely: Xray, Hysteria2 and their files inside it, and the three forwards on this server.
# Safe to repeat, and safe on a stopped VPS (only the server side is removed then).
#   vpn_remove <vps>
vpn_remove() {
  local vps="${1:?vps}" ext ip tls_ext
  ext=$(vpn_get_port "$vps")
  ip=$(get_ip "$vps" 2>/dev/null || true)
  if [ -n "$ext" ]; then
    # close an open QR/subscription page of this VPN: its links stop working now
    pkill -f "vpn_once_server.py .* $((ext + 1)) " 2>/dev/null || true
    [ -n "$ip" ] || ip=$(awk -F'|' -v p="$ext" '$1 == "tcp" && $3 == p && $5 == p { print $4; exit }' "$PORT_FORWARD_RULES_FILE" 2>/dev/null)
    if [ -n "$ip" ]; then
      tls_ext=$((ext + VPN_TLS_PORT_OFFSET))
      port_forward_delete_rule tcp 0.0.0.0 "$ext" "$ip" "$ext"
      port_forward_remove_rule_from_file "$PORT_FORWARD_RULES_FILE" tcp 0.0.0.0 "$ext" "$ip" "$ext"
      port_forward_delete_rule udp 0.0.0.0 "$ext" "$ip" "$VPN_HY_INNER_PORT"
      port_forward_remove_rule_from_file "$PORT_FORWARD_RULES_FILE" udp 0.0.0.0 "$ext" "$ip" "$VPN_HY_INNER_PORT"
      port_forward_delete_rule tcp 0.0.0.0 "$tls_ext" "$ip" "$VPN_TLS_INNER_PORT"
      port_forward_remove_rule_from_file "$PORT_FORWARD_RULES_FILE" tcp 0.0.0.0 "$tls_ext" "$ip" "$VPN_TLS_INNER_PORT"
      save_iptables
    fi
  fi
  if is_vps_running "$vps"; then
    incus exec "$vps" --env D="$VPN_GUEST_DIR" -- sh -c '
      systemctl disable --now vpsforge-vpn >/dev/null 2>&1 || true
      systemctl disable --now vpsforge-hy2 >/dev/null 2>&1 || true
      rc-service vpsforge-hy2 stop >/dev/null 2>&1 || true
      rc-update del vpsforge-hy2 default >/dev/null 2>&1 || true
      pkill -x hysteria >/dev/null 2>&1 || true
      rc-service vpsforge-vpn stop >/dev/null 2>&1 || true
      rc-update del vpsforge-vpn default >/dev/null 2>&1 || true
      pkill -x xray >/dev/null 2>&1 || true
      rm -f /etc/systemd/system/vpsforge-hy2.service /etc/init.d/vpsforge-hy2 /usr/local/bin/hysteria
      rm -f /etc/systemd/system/vpsforge-vpn.service /etc/init.d/vpsforge-vpn /usr/local/bin/xray
      systemctl daemon-reload >/dev/null 2>&1 || true
      rm -rf "$D"
    ' </dev/null >/dev/null 2>&1 || true
  fi
  incus config unset "$vps" user.vpsforge.vpn >/dev/null 2>&1 || true
  incus config unset "$vps" user.vpsforge.vpn_sni >/dev/null 2>&1 || true
  incus config unset "$vps" user.vpsforge.vpn_tls_sni >/dev/null 2>&1 || true
  incus config unset "$vps" user.vpsforge.vpn_hy_sni >/dev/null 2>&1 || true
  sync_vps_metadata "$vps" >/dev/null 2>&1 || true
  return 0
}
