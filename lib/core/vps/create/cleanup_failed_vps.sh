#!/bin/bash
# Remove everything a failed or interrupted VPS creation could have reserved:
# the instance and its disk, the IP and SSH port forwards, FORWARD rules, saved
# port-forward lines and proxy config. Safe to run more than once.
#   cleanup_failed_vps <name> <ip> <port> [reason]
cleanup_failed_vps() {
  local name="${1:?name}" ip="${2:-}" port="${3:-}" reason="${4:-}"

  if [ -n "$ip" ]; then
    remove_ip "$ip"
    # During a reinstall the IP still belongs to the original VPS: keep its custom port-forwards.
    [ "${VPS_KEEP_FORWARDS:-0}" = "1" ] || { port_forward_delete_rules_for_ip "$ip"; remove_vps_forward_rules "$ip"; }
  fi
  [ -n "$port" ] && remove_port "$port"

  # The server may still be creating it in the background even though the client was stopped.
  cancel_instance_creation "$name"
  if incus info "$name" >/dev/null 2>&1; then
    incus delete "$name" --force >/dev/null 2>&1 || true
  fi
  # one more look: an operation that finished just now could still have produced the instance
  sleep 1
  incus info "$name" >/dev/null 2>&1 && incus delete "$name" --force >/dev/null 2>&1
  rm -f "$CADDY_CONF_DIR/${name}.caddy" 2>/dev/null || true
  pending_operation_clear "$name"
  save_iptables 2>/dev/null || true
  reclaim_pool_space

  [ -n "$reason" ] && echo "   (VPS '$name' was not created: $reason)"
  return 0
}
