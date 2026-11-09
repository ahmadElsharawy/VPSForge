#!/bin/bash
# Delete a tunnel completely: close its public side and forget it.
#   tunnel_delete <vps> <tunnel_port>
tunnel_delete() {
  local vps="${1:?vps}" tport="${2:?tunnel port}" rec lport ext domain state
  rec=$(tunnel_get_records "$vps" | awk -F'|' -v p="$tport" '$1 == p { print; exit }')
  [ -n "$rec" ] || return 0
  IFS='|' read -r _ lport ext domain state <<< "$rec"
  tunnel_public_stop "$vps" "$tport" "$ext" "$domain"
  tunnel_access_remove "$vps" "$tport"
  tunnel_record_delete "$vps" "$tport"
}
