#!/bin/bash
# Remove one tunnel record from a VPS.
#   tunnel_record_delete <vps> <tunnel_port>
tunnel_record_delete() {
  local vps="${1:?vps}" tport="${2:?tunnel port}"
  tunnel_get_records "$vps" | awk -F'|' -v p="$tport" '$1 != p' | tunnel_put_records "$vps"
}
