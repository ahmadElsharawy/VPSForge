#!/bin/bash
# Edit a tunnel: the same questions as when adding, already filled with the current values.
# Nothing changes until the last confirmation; the new settings then replace the old ones.
#   tunnel_edit <vps> <tunnel_port>
tunnel_edit() {
  local vps="${1:?vps}" tport="${2:?tunnel port}" rec lport ext domain state was_active=0
  rec=$(tunnel_get_records "$vps" | awk -F'|' -v p="$tport" '$1 == p { print; exit }')
  [ -n "$rec" ] || { echo "No tunnel on port $tport of $vps."; return 1; }
  IFS='|' read -r _ lport ext domain state <<< "$rec"
  [ "$state" = "active" ] && was_active=1

  TW_VPS="$vps"; TW_IP=$(get_ip "$vps"); TW_TPORT="$tport"; TW_LPORT="$lport"
  TW_DOMAIN="$domain"; TW_EXTPORT="$ext"
  TW_EDIT_TPORT="$tport"; TW_EDIT_EXT="$ext"; TW_EDIT_DOMAIN="$domain"
  pref_set tunnel_port "$tport"; pref_set tunnel_local_port "$lport"

  clear
  echo "EDIT TUNNEL  ($vps, port $tport)   - Enter keeps the current value"
  if ! run_wizard tunnel_wizard_step_ports tunnel_wizard_step_address tunnel_wizard_step_confirm; then
    TW_EDIT_TPORT=""; TW_EDIT_EXT=""; TW_EDIT_DOMAIN=""; TW_TPORT="$tport"
    echo "Nothing was changed."
    return 0
  fi
  TW_EDIT_TPORT=""; TW_EDIT_EXT=""; TW_EDIT_DOMAIN=""

  tunnel_delete "$vps" "$tport"
  if ! tunnel_create "$vps" "$TW_TPORT" "$TW_LPORT" "$TW_EXTPORT" "$TW_DOMAIN"; then
    echo "ERROR: the new settings could not be applied. The old tunnel was removed; add it again from the menu."
    return 1
  fi
  [ "$was_active" -eq 1 ] || tunnel_stop "$vps" "$TW_TPORT"
  echo "Saved."
}
