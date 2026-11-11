#!/bin/bash
# Sync VPS network settings (IP, port forwards, proxy config) to container metadata.
sync_vps_metadata() {
  local name="$1" ip conf_file proxy_b64
  ip=$(get_ip "$name" 2>/dev/null || true)
  [ -n "$ip" ] || return 0

  incus config set "$name" user.vpsforge.ip "$ip" 2>/dev/null || true

  # 1. Sync Port Forwards
  _sync_vps_port_forwards_metadata "$name" "$ip"

  # 2. Sync Proxy Configurations (Caddy)
  conf_file="/etc/caddy/vpsforge/${name}.caddy"
  if [ -f "$conf_file" ]; then
    proxy_b64=$(base64 -w0 "$conf_file" 2>/dev/null || base64 "$conf_file" 2>/dev/null || true)
    incus config set "$name" user.vpsforge.proxy "$proxy_b64" 2>/dev/null || true
  else
    incus config unset "$name" user.vpsforge.proxy 2>/dev/null || true
  fi
}
