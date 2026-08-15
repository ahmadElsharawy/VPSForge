#!/bin/bash
# VPSForge v1.0.0 — Caddy proxy metadata restore.

restore_vps_proxy_metadata() {
  local name="$1" ip
  ip=$(get_ip "$name" 2>/dev/null || true)
  [ -n "$ip" ] || return 0

  local conf_file="$CADDY_CONF_DIR/${name}.caddy"
  [ -f "$conf_file" ] || return 0

  # Re-read the Caddy config and update any old IPs to the current IP
  if grep -qE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$conf_file"; then
    sed -i -E "s|reverse_proxy [a-z]*://[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:|reverse_proxy http://${ip}:|g" "$conf_file" 2>/dev/null || true
    systemctl reload-or-restart caddy >/dev/null 2>&1 || true
  fi
}
