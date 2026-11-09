#!/bin/bash
# Stop a tunnel: close its public side. The record stays so it can be started again.
#   tunnel_stop <vps> <tunnel_port>
tunnel_stop() {
  local vps="${1:?vps}" tport="${2:?tunnel port}" rec lport ext domain state
  rec=$(tunnel_get_records "$vps" | awk -F'|' -v p="$tport" '$1 == p { print; exit }')
  [ -n "$rec" ] || { echo "ERROR: no tunnel on port $tport of $vps."; return 1; }
  IFS='|' read -r _ lport ext domain state <<< "$rec"
  tunnel_public_stop "$vps" "$tport" "$ext" "$domain"
  tunnel_record_set "$vps" "$tport" "$lport" "$ext" "$domain" stopped
}
