#!/bin/bash
# Start a saved tunnel: allow tunnels inside the VPS and open its public side.
#   tunnel_start <vps> <tunnel_port>
tunnel_start() {
  local vps="${1:?vps}" tport="${2:?tunnel port}" rec lport ext domain state
  rec=$(tunnel_get_records "$vps" | awk -F'|' -v p="$tport" '$1 == p { print; exit }')
  [ -n "$rec" ] || { echo "ERROR: no tunnel on port $tport of $vps."; return 1; }
  IFS='|' read -r _ lport ext domain state <<< "$rec"

  is_vps_running "$vps" || { echo "ERROR: $vps is not running. Start it first (main menu 3)."; return 1; }
  enable_vps_tunnel_access "$vps" || { echo "ERROR: could not enable tunnels inside $vps (is ssh installed there?)."; return 1; }
  tunnel_public_start "$vps" "$tport" "$ext" "$domain" || return 1
  tunnel_record_set "$vps" "$tport" "$lport" "$ext" "$domain" active
}
