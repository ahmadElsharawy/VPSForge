#!/bin/bash
# After a successful import: delete the old VPS that was put aside, with its IP, port and forwards.
#   finalize_replaced_vps <hold_name> <old_ip> <old_port> <caddy_backup_file>
finalize_replaced_vps() {
  local hold="${1:?hold name}" old_ip="${2:-}" old_port="${3:-}" caddy_bak="${4:-}"
  [ -n "$old_ip" ] && port_forward_delete_rules_for_ip "$old_ip"
  [ -n "$old_ip" ] && remove_ip "$old_ip"
  [ -n "$old_port" ] && remove_port "$old_port"
  incus delete "$hold" --force >/dev/null 2>&1 || true
  [ -n "$caddy_bak" ] && rm -f "$caddy_bak"
  return 0
}
