#!/bin/bash
# Steps of vpn_create (run under run_guarded).
#   _vpn_create_steps <vps> <public_tcp_port>
_vpn_create_steps() {
  local vps="${1:?vps}" ext="${2:?public port}" ip
  is_vps_running "$vps" || { echo "ERROR: $vps is not running. Start it first (main menu 3)."; return 1; }
  ip=$(get_ip "$vps")
  [ -n "$ip" ] || { echo "ERROR: $vps has no IP address."; return 1; }
  echo "[1/3] Installing Xray inside $vps..."
  vpn_install_packages "$vps" || return 1
  echo "[2/3] Starting the VPN (VLESS + Reality)..."
  incus config set "$vps" user.vpsforge.vpn "$ext" || return 1
  vpn_server_setup "$vps" || return 1
  echo "[3/3] Opening TCP port $ext on the server..."
  port_forward_apply_rule tcp 0.0.0.0 "$ext" "$ip" "$ext" || { echo "ERROR: iptables refused the rule."; return 1; }
  port_forward_append_rule_to_file "$PORT_FORWARD_RULES_FILE" tcp 0.0.0.0 "$ext" "$ip" "$ext"
  save_iptables
  sync_vps_metadata "$vps"
  return 0
}
