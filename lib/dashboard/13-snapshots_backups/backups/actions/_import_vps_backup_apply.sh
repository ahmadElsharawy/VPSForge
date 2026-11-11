#!/bin/bash
# The unpack-and-configure half of import_vps_backup. It uses the variables of
# import_vps_backup (file_path, target_name, rules_to_apply, domains_to_apply,
# caddy_conflicts_to_remove, proxy_decoded). Always call it through run_guarded.
_import_vps_backup_apply() {
  pending_operation_set "$target_name" "" ""
  _import_unpack_archive "$file_path" "$target_name" || return 1

  mark_vps_state "$target_name" importing

  # The address was decided before the import (see import_vps_backup). The login saved in the backup is kept;
  # the old address and port stored in it are not ours any more.
  local kept_user kept_pw
  kept_user=$(get_vps_user "$target_name"); kept_pw=$(get_vps_password "$target_name")
  incus config unset "$target_name" user.vpsforge.ip >/dev/null 2>&1 || true
  incus config unset "$target_name" user.vpsforge.ssh_port >/dev/null 2>&1 || true

  _import_configure_guest_network "$target_name" "$new_ip" "$new_num" "$new_port"

  _import_restore_port_forwards
  _import_restore_proxy

  tunnel_reconcile_import "$target_name" "$new_ip" "$new_port" renew   # its tunnels must match what really came back
  sync_vps_metadata "$target_name" || true
  incus config set "$target_name" user.vpsforge.last_restore "$(date '+%Y-%m-%d %H:%M:%S UTC')" 2>/dev/null || true

  mark_vps_state "$target_name" ""
  pending_operation_clear "$target_name"
  echo "[ 100% ] Success: $target_name restored at $new_ip (SSH Port $new_port)"
}
