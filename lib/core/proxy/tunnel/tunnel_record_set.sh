#!/bin/bash
# Add a tunnel record to a VPS, or replace the one with the same tunnel port.
#   tunnel_record_set <vps> <tunnel_port> <my_pc_port> <public_port|""> <domain|""> <active|stopped>
tunnel_record_set() {
  local vps="${1:?vps}" tport="${2:?tunnel port}" lport="${3:?pc port}" ext="${4:-}" domain="${5:-}" state="${6:-stopped}"
  {
    tunnel_get_records "$vps" | awk -F'|' -v p="$tport" '$1 != p'
    echo "${tport}|${lport}|${ext}|${domain}|${state}"
  } | tunnel_put_records "$vps"
}
