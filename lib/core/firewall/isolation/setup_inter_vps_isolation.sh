#!/bin/bash
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

  if command -v ip6tables >/dev/null 2>&1; then   # the bridge may carry IPv6 too: no VPS-to-VPS traffic there either
    ip6tables -C FORWARD -i incusbr0 -o incusbr0 -j DROP 2>/dev/null || \
      ip6tables -I FORWARD 1 -i incusbr0 -o incusbr0 -j DROP 2>/dev/null || true
  fi

  local legacy_rule
  while read -r legacy_rule; do
    [ -n "$legacy_rule" ] || continue
    iptables ${legacy_rule/-A/-D} 2>/dev/null || true
  done < <(iptables -S FORWARD 2>/dev/null | grep -E "^-A FORWARD -d ${NETWORK_PREFIX//./\\.}\.[0-9]+/32 -p (tcp|udp) -m (tcp|udp) --dport [0-9]+( -m state --state NEW,RELATED,ESTABLISHED)? -j ACCEPT$" || true)

  purge_invalid_dnat_rules
  save_iptables
}
