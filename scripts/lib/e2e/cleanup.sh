#!/bin/bash
# Remove containers, network addresses, port forwards, and proxy configurations created by e2e test.
cleanup() {
  local ip port
  ip=$(get_ip "$T" 2>/dev/null || true)
  [ -n "$ip" ] && { remove_ip "$ip"; port_forward_delete_rules_for_ip "$ip"; }
  incus delete "$T" --force >/dev/null 2>&1 || true
  incus delete "${T}-r" --force >/dev/null 2>&1 || true
  incus delete "${T}-imp" --force >/dev/null 2>&1 || true
  rm -f "$CADDY_CONF_DIR/$T.caddy" /tmp/e2e_askpass.sh 2>/dev/null
  save_iptables
}
