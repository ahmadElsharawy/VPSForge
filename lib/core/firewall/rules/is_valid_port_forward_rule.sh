#!/bin/bash
# Return 0 only if a saved forward rule is safe: tcp/udp, a plain IPv4 (or empty), ports 1-65535, and
# not the SSH/web ports 22/80/443 on the host. Used for rules read from backups and snapshots.
#   is_valid_port_forward_rule <proto> <ext_ip> <ext_port> <int_port>
is_valid_port_forward_rule() {
  local proto="${1:-}" ext_ip="${2:-}" ext_port="${3:-}" int_port="${4:-}"
  [[ "$proto" =~ ^(tcp|udp)$ ]] || return 1
  if [ -n "$ext_ip" ] && [ "$ext_ip" != "0.0.0.0" ]; then
    [[ "$ext_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  fi
  [[ "$ext_port" =~ ^[0-9]{1,5}$ ]] && [ "$ext_port" -ge 1 ] && [ "$ext_port" -le 65535 ] || return 1
  [[ "$int_port" =~ ^[0-9]{1,5}$ ]] && [ "$int_port" -ge 1 ] && [ "$int_port" -le 65535 ] || return 1
  case "$ext_port" in 22|80|443) return 1;; esac
  return 0
}
