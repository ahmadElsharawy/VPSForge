#!/bin/bash
# After a restore/import, point the VPS's reverse-proxy config at its current IP.
restore_vps_proxy_metadata() {
  local name="$1" ip
  ip=$(get_ip "$name" 2>/dev/null || true)
  [ -n "$ip" ] || return 0
  update_vps_proxy_ip "$name" "$ip"
}
