#!/bin/bash
# Pick the public UDP port for a new Hysteria2: the first port of VPN_HY_PORTS that nothing on this
# server uses (networks that block most UDP ports usually let these through), else <fallback>.
#   _vpn_pick_hy_port <fallback_port>
_vpn_pick_hy_port() {
  local fallback="${1:?port}" p
  for p in $VPN_HY_PORTS; do
    [ -z "$(host_port_owner "$p" udp)" ] || continue
    awk -F'|' -v p="$p" '$1 == "udp" && $3 == p { f = 1 } END { exit !f }' "$PORT_FORWARD_RULES_FILE" 2>/dev/null && continue
    # Also reject a port already taken by a live UDP DNAT rule. The rules file is written only at the end
    # of VPN creation, so two VPNs created close together would otherwise both pick the first free port;
    # the iptables rule appears as soon as the first one is applied (and _vpn_create_steps holds a lock).
    iptables -t nat -S PREROUTING 2>/dev/null | grep -qE -- "-p udp -m udp --dport ${p} -j DNAT" && continue
    echo "$p"
    return 0
  done
  echo "$fallback"
}
