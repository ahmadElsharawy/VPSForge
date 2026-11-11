#!/bin/bash
# Apply updated settings to an active tunnel, rolling back if tunnel_create fails.
#   _tunnel_save_active_edit <vps> <old_tport> <old_lport> <old_ext> <old_domain>
_tunnel_save_active_edit() {
  local vps="${1:?vps}" tport="${2:?tunnel port}" lport="${3:?local port}" ext="${4:-}" domain="${5:-}"
  tunnel_public_stop "$vps" "$tport" "$ext" "$domain"
  tunnel_record_delete "$vps" "$tport"
  if ! tunnel_create "$vps" "$TW_TPORT" "$TW_LPORT" "$TW_EXTPORT" "$TW_DOMAIN"; then
    echo "ERROR: the new settings could not be applied. Putting the old tunnel back..."
    tunnel_record_set "$vps" "$tport" "$lport" "$ext" "$domain" stopped
    tunnel_start "$vps" "$tport" || echo "The old tunnel is saved but stopped; start it from the list."
    TW_TPORT="$tport"
    return 1
  fi
  [ "$TW_TPORT" = "$tport" ] || tunnel_access_remove "$vps" "$tport"   # only now: a failed edit keeps the old login
  echo "Saved."
  [ "$TW_LPORT" = "$lport" ] && [ "$TW_TPORT" = "$tport" ] || echo "NOTE: on the computer, choose \"Show the command\" > 1 and run it again so it uses the new ports."
  return 0
}
