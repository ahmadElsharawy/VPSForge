#!/bin/bash
purge_invalid_dnat_rules() {
  local rule
  while read -r rule; do
    [ -n "$rule" ] || continue
    iptables -t nat -D PREROUTING $rule 2>/dev/null || true
  done < <(iptables -t nat -S PREROUTING 2>/dev/null | grep -E '\-d 0\.0\.0\.0' | sed 's/^-A PREROUTING //' || true)

  while read -r rule; do
    [ -n "$rule" ] || continue
    if [[ "$rule" != *"incusbr0"* ]] && [[ "$rule" != *"-d "* ]]; then
      iptables -t nat -D PREROUTING $rule 2>/dev/null || true
    fi
  done < <(iptables -t nat -S PREROUTING 2>/dev/null | grep -E '\-j DNAT' | sed 's/^-A PREROUTING //' || true)
}
