#!/bin/bash
# Manually edit a VPS Caddy configuration with nano and reload Caddy safely.
#   _proxy_action_edit_conf <vps> <conf>
_proxy_action_edit_conf() {
  local vps="${1:?vps}" conf="${2:?conf}"
  cp -f "$conf" "${conf}.bak"
  nano "$conf"
  if caddy_apply_or_rollback "$conf" "${conf}.bak"; then
    echo "Saved and reloaded."
    sync_vps_metadata "$vps"
  fi
  pause
}
