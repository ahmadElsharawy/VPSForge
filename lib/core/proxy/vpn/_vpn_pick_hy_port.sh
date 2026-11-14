#!/bin/bash
# Pick the public UDP port for a new Hysteria2: the first port of VPN_HY_PORTS that nothing on this
# server uses (networks that block most UDP ports usually let these through), else <fallback>.
#   _vpn_pick_hy_port <fallback_port>
_vpn_pick_hy_port() {
  local fallback="${1:?port}" p
  for p in $VPN_HY_PORTS; do
    [ -z "$(host_port_owner "$p" udp)" ] || continue
    awk -F'|' -v p="$p" '$1 == "udp" && $3 == p { f = 1 } END { exit !f }' "$PORT_FORWARD_RULES_FILE" 2>/dev/null && continue
    echo "$p"
    return 0
  done
  echo "$fallback"
}
