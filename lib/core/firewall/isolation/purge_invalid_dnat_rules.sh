#!/bin/bash
purge_invalid_dnat_rules() {
  local rule
  while read -r rule; do
    [ -n "$rule" ] || continue
    iptables -t nat -D PREROUTING $rule 2>/dev/null || true
  done < <(iptables -t nat -S PREROUTING 2>/dev/null | grep -E '\-d 0\.0\.0\.0' | sed 's/^-A PREROUTING //' || true)

  while read -r rule; do
    [ -n "$rule" ] || continue
    # Only our own rules (destination inside the VPS network); the owner's other DNAT rules stay.
    if [[ "$rule" != *"incusbr0"* ]] && [[ "$rule" != *"-d "* ]] && [[ "$rule" == *"--to-destination ${NETWORK_PREFIX:-@none@}."* ]]; then
      iptables -t nat -D PREROUTING $rule 2>/dev/null || true
    fi
  done < <(iptables -t nat -S PREROUTING 2>/dev/null | grep -E '\-j DNAT' | sed 's/^-A PREROUTING //' || true)
}
