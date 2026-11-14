#!/bin/bash
# Pick the public UDP port for a new Hysteria2: 443 (the QUIC port, which networks that block
# other UDP ports usually let through) when nothing on this server uses UDP 443, else <fallback>.
#   _vpn_pick_hy_port <fallback_port>
_vpn_pick_hy_port() {
  local fallback="${1:?port}"
  if [ -z "$(host_port_owner 443 udp)" ] \
     && ! awk -F'|' '$1 == "udp" && $3 == 443 { f = 1 } END { exit !f }' "$PORT_FORWARD_RULES_FILE" 2>/dev/null; then
    echo 443
  else
    echo "$fallback"
  fi
}
