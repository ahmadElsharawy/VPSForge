#!/bin/bash
# Save a new tunnel and start it.
#   tunnel_create <vps> <tunnel_port> <my_pc_port> <public_port|""> <domain|"">
tunnel_create() {
  local vps="${1:?vps}" tport="${2:?tunnel port}" lport="${3:?pc port}" ext="${4:-}" domain="${5:-}" pending
  # a login still waiting to be removed for this port (deleted while the VPS was stopped) must not
  # be removed later from under the new tunnel: clear it now and forget the note
  pending=$(incus config get "$vps" user.vpsforge.tunnel_cleanup 2>/dev/null || true)
  if [ -n "$pending" ]; then
    tunnel_access_remove "$vps" "$tport"
    pending=$(tr ' ' '\n' <<< "$pending" | grep -vx "$tport" | tr '\n' ' ')
    pending="${pending% }"
    if [ -n "$pending" ]; then incus config set "$vps" user.vpsforge.tunnel_cleanup "$pending"; else incus config unset "$vps" user.vpsforge.tunnel_cleanup; fi >/dev/null 2>&1
  fi
  tunnel_record_set "$vps" "$tport" "$lport" "$ext" "$domain" stopped
  if ! tunnel_start "$vps" "$tport"; then
    tunnel_record_delete "$vps" "$tport"
    return 1
  fi
}
