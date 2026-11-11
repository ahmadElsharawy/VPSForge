#!/bin/bash
# Reapplies last restore timestamp, tunnels, port forwards, and proxy routes after restore.
_restore_snapshot_post_config() {
  local name="${1:-}" kept_tunnels="${2:-}"
  incus config set "$name" user.vpsforge.last_restore "$(date '+%Y-%m-%d %H:%M:%S UTC')" 2>/dev/null || true
  if [ -n "$kept_tunnels" ]; then
    incus config set "$name" "user.vpsforge.tunnels=$kept_tunnels" >/dev/null 2>&1
  else
    incus config unset "$name" user.vpsforge.tunnels >/dev/null 2>&1 || true
  fi
  restore_vps_port_forwards_metadata "$name"
  tunnel_reconcile_import "$name" "$(get_ip "$name")" "$(get_vps_saved_port "$name")"
}
