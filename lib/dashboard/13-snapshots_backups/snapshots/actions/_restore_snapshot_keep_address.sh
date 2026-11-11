#!/bin/bash
# After a snapshot restore, put back the VPS's CURRENT IP and SSH port: the snapshot may hold
# an older address that another VPS uses now.
#   _restore_snapshot_keep_address <name> <ip_before_restore> <port_before_restore>
_restore_snapshot_keep_address() {
  local name="${1:-}" ip="${2:-}" port="${3:-}" restored_ip
  [ -n "$name" ] && [ -n "$ip" ] || return 0
  restored_ip=$(incus config get "$name" user.vpsforge.ip 2>/dev/null || true)
  if [ "$restored_ip" != "$ip" ]; then
    echo "Keeping the current address $ip (the snapshot had ${restored_ip:-none})."
    configure_vps_network_device "$name" "$ip" >/dev/null 2>&1 || true
    incus config set "$name" user.vpsforge.ip "$ip" >/dev/null 2>&1 || true
    RESTORE_FIX_GUEST_IP="$ip"
  fi
  [ -n "$port" ] && set_vps_saved_port "$name" "$port" >/dev/null 2>&1 || true
}
