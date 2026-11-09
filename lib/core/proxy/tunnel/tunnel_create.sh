#!/bin/bash
# Save a new tunnel and start it.
#   tunnel_create <vps> <tunnel_port> <my_pc_port> <public_port|""> <domain|"">
tunnel_create() {
  local vps="${1:?vps}" tport="${2:?tunnel port}" lport="${3:?pc port}" ext="${4:-}" domain="${5:-}"
  tunnel_record_set "$vps" "$tport" "$lport" "$ext" "$domain" stopped
  if ! tunnel_start "$vps" "$tport"; then
    tunnel_record_delete "$vps" "$tport"
    return 1
  fi
}
