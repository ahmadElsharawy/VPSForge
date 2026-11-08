#!/bin/bash
# Point every reverse_proxy target of VPS <name> at <new_ip>, keeping the
# scheme (http/https), path and port. Called whenever a VPS IP changes.
#   update_vps_proxy_ip <name> <new_ip>
update_vps_proxy_ip() {
  local name="${1:?name}" new_ip="${2:?new_ip}" conf="$CADDY_CONF_DIR/${1}.caddy"
  [ -f "$conf" ] || return 0

  sed -i -E "s#(reverse_proxy[^{]*://)[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:#\1${new_ip}:#g" "$conf"
  if command -v caddy >/dev/null 2>&1 && caddy validate --config "$MAIN_CADDYFILE" >/dev/null 2>&1; then
    systemctl reload-or-restart caddy >/dev/null 2>&1 || true
  fi
}
