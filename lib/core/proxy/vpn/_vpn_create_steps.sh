#!/bin/bash
# Steps of vpn_create (run under run_guarded).
#   _vpn_create_steps <vps> <public_port> <reality_sni> <tls_sni> <hysteria2_sni>
_vpn_create_steps() {
  local vps="${1:?vps}" ext="${2:?public port}" sni="${3:-$VPN_SNI}" tls_sni="${4:-$VPN_TLS_SNI}" hy_sni="${5:-$VPN_HY_SNI}" ip tls_ext
  is_vps_running "$vps" || { echo "ERROR: $vps is not running. Start it first (main menu 3)."; return 1; }
  tls_ext=$((ext + VPN_TLS_PORT_OFFSET))
  [ "$tls_ext" -le 65535 ] || { echo "ERROR: port $ext is too high (the VLESS+TLS port $tls_ext would pass 65535)."; return 1; }
  ip=$(get_ip "$vps")
  [ -n "$ip" ] || { echo "ERROR: $vps has no IP address."; return 1; }
  echo "[1/3] Installing Xray and Hysteria2 inside $vps..."
  vpn_install_packages "$vps" || return 1
  echo "[2/3] Starting the VPN (Reality, TLS and Hysteria2)..."
  incus config set "$vps" user.vpsforge.vpn "$ext" || return 1
  incus config set "$vps" user.vpsforge.vpn_sni "$sni" || return 1
  incus config set "$vps" user.vpsforge.vpn_tls_sni "$tls_sni" || return 1
  incus config set "$vps" user.vpsforge.vpn_hy_sni "$hy_sni" || return 1
  vpn_server_setup "$vps" || return 1
  echo "[3/3] Opening TCP $ext, UDP $ext and TCP $tls_ext on the server..."
  port_forward_apply_rule tcp 0.0.0.0 "$ext" "$ip" "$ext" || { echo "ERROR: iptables refused the rule."; return 1; }
  port_forward_append_rule_to_file "$PORT_FORWARD_RULES_FILE" tcp 0.0.0.0 "$ext" "$ip" "$ext"
  port_forward_apply_rule udp 0.0.0.0 "$ext" "$ip" "$VPN_HY_INNER_PORT" || { echo "ERROR: iptables refused the UDP rule."; return 1; }
  port_forward_append_rule_to_file "$PORT_FORWARD_RULES_FILE" udp 0.0.0.0 "$ext" "$ip" "$VPN_HY_INNER_PORT"
  port_forward_apply_rule tcp 0.0.0.0 "$tls_ext" "$ip" "$VPN_TLS_INNER_PORT" || { echo "ERROR: iptables refused the TLS rule."; return 1; }
  port_forward_append_rule_to_file "$PORT_FORWARD_RULES_FILE" tcp 0.0.0.0 "$tls_ext" "$ip" "$VPN_TLS_INNER_PORT"
  save_iptables
  sync_vps_metadata "$vps"
  return 0
}
