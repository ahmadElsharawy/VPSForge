#!/bin/bash
# Remove outdated per-port FORWARD ACCEPT rules replaced by global DNAT/ESTABLISHED rules.
_purge_legacy_forward_rules() {
  local prefix="${1:-${NETWORK_PREFIX:-}}" legacy_rule
  [ -n "$prefix" ] || return 0

  while read -r legacy_rule; do
    [ -n "$legacy_rule" ] || continue
    iptables ${legacy_rule/-A/-D} 2>/dev/null || true
  done < <(iptables -S FORWARD 2>/dev/null | grep -E "^-A FORWARD -d ${prefix//./\\.}\.[0-9]+/32 -p (tcp|udp) -m (tcp|udp) --dport [0-9]+( -m state --state NEW,RELATED,ESTABLISHED)? -j ACCEPT$" || true)
}
