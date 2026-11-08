#!/bin/bash
_rollback_vps_full() {
  local name="$1" ip="$2" port="$3"
  echo "Deleting incomplete VPS..."
  remove_ip "$ip"
  remove_port "$port"
  [ -n "$ip" ] && [ "${VPS_KEEP_FORWARDS:-0}" != "1" ] && port_forward_delete_rules_for_ip "$ip"
  incus delete "$name" --force >/dev/null 2>&1 || true
}
