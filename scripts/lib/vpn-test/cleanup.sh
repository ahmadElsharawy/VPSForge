#!/bin/bash
# Clean up VPN test containers, IP allocations, and port forwards.
cleanup() {
  local n ip
  for n in "$S" "$C"; do
    ip=$(get_ip "$n" 2>/dev/null || true)
    [ -n "$ip" ] && { remove_ip "$ip"; port_forward_delete_rules_for_ip "$ip"; }
    incus delete "$n" --force >/dev/null 2>&1 || true
  done
  save_iptables
}
