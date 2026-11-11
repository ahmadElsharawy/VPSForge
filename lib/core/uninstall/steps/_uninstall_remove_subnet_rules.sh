#!/bin/bash
# Remove leftover DNAT and FORWARD iptables rules mentioning the VPS subnet.
#   _uninstall_remove_subnet_rules <subnet>
_uninstall_remove_subnet_rules() {
  local subnet="$1" line
  [ -n "$subnet" ] && [ "${UNINSTALL_DRY_RUN:-0}" != "1" ] || return 0

  while read -r line; do
    [ -n "$line" ] || continue
    # shellcheck disable=SC2086
    iptables -t nat -D PREROUTING $line >/dev/null 2>&1 || true
  done < <(iptables -t nat -S PREROUTING 2>/dev/null | grep -E "DNAT.*--to-destination ${NETWORK_PREFIX}\." | sed 's/^-A PREROUTING //')

  while read -r line; do
    [ -n "$line" ] || continue
    # shellcheck disable=SC2086
    iptables -D FORWARD $line >/dev/null 2>&1 || true
  done < <(iptables -S FORWARD 2>/dev/null | grep -E -- "-[ds] ${NETWORK_PREFIX//./\.}\." | sed 's/^-A FORWARD //')
}
