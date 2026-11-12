#!/bin/bash
# After a restore/import, point the VPS's reverse-proxy config at its current IP.
restore_vps_proxy_metadata() {
  local name="$1" ip conf_file proxy_b64
  ip=$(get_ip "$name" 2>/dev/null || true)
  [ -n "$ip" ] || return 0
  conf_file="$CADDY_CONF_DIR/${name}.caddy"
  if [ ! -f "$conf_file" ]; then
    proxy_b64=$(incus config get "$name" user.vpsforge.proxy 2>/dev/null || true)
    if [ -n "$proxy_b64" ]; then
      mkdir -p "$CADDY_CONF_DIR"
      echo "$proxy_b64" | (base64 -d 2>/dev/null || base64 -D 2>/dev/null || true) > "$conf_file"
    fi
  fi
  update_vps_proxy_ip "$name" "$ip"
}
