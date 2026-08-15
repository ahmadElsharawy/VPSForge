#!/bin/bash
# VPSForge v1.0.0 — Inter-VPS isolation and legacy rule cleanup.

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

setup_inter_vps_isolation() {
  [ -n "${NETWORK_PREFIX:-}" ] || return 0
  local subnet="${NETWORK_PREFIX}.0/24"

  modprobe br_netfilter 2>/dev/null || true
  sysctl -w net.bridge.bridge-nf-call-iptables=1 >/dev/null 2>&1 || true

  iptables -t nat -C POSTROUTING -s "$subnet" ! -d "$subnet" -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s "$subnet" ! -d "$subnet" -j MASQUERADE

  iptables -t nat -C POSTROUTING -s "$subnet" -d "$subnet" -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s "$subnet" -d "$subnet" -j MASQUERADE

  iptables -C FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
    iptables -I FORWARD 1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

  iptables -C FORWARD -m conntrack --ctstate DNAT -j ACCEPT 2>/dev/null || \
    iptables -I FORWARD 2 -m conntrack --ctstate DNAT -j ACCEPT

  iptables -C FORWARD -i incusbr0 ! -o incusbr0 -j ACCEPT 2>/dev/null || \
    iptables -I FORWARD 3 -i incusbr0 ! -o incusbr0 -j ACCEPT

  if [ -n "${INCUS_GATEWAY:-}" ]; then
    iptables -C FORWARD -i incusbr0 -s "$subnet" -d "$INCUS_GATEWAY" -j ACCEPT 2>/dev/null || \
      iptables -I FORWARD 4 -i incusbr0 -s "$subnet" -d "$INCUS_GATEWAY" -j ACCEPT
  fi

  iptables -C FORWARD -i incusbr0 -o incusbr0 -j DROP 2>/dev/null || \
    iptables -A FORWARD -i incusbr0 -o incusbr0 -j DROP

  iptables -C FORWARD -s "$subnet" -d "$subnet" -j DROP 2>/dev/null || \
    iptables -A FORWARD -s "$subnet" -d "$subnet" -j DROP

  purge_invalid_dnat_rules
  save_iptables
}
