#!/bin/bash
# Displays comprehensive configuration, resource usage, and history details for a VPS.

details() {
  local name="$1" ip
  incus info "$name" >/dev/null 2>&1 || { echo "ERROR: VPS '$name' does not exist."; return 1; }

  ip=$(get_ip "$name" 2>/dev/null || true); [ -n "$ip" ] || ip="-"

  _details_print_identity "$name" "$ip"
  _details_print_resources "$name"
  _details_print_port_forwards "$ip"
  _details_print_proxy_domains "$name"
  _details_print_snapshots "$name"
  _details_print_backups "$name"
}
