#!/bin/bash
# Delete EVERY FORWARD rule that mentions a VPS address (accept rules in both directions,
# any port). Used when a VPS is deleted, so nothing about it stays in the firewall.
#   remove_vps_forward_rules <ip>
remove_vps_forward_rules() {
  local ip="${1:-}" rule
  [ -n "$ip" ] || return 0
  while read -r rule; do
    [ -n "$rule" ] || continue
    # shellcheck disable=SC2086
    iptables -D FORWARD $rule >/dev/null 2>&1 || true
  done < <(iptables -S FORWARD 2>/dev/null | grep -E -- "-[ds] ${ip//./\\.}/32( |\$)" | sed 's/^-A FORWARD //')
  return 0
}
