#!/bin/bash
# Print the public UDP port of a VPS's Hysteria2. VPNs made before it could differ from the
# VPN's TCP port have none saved: they use the VPN's port.
#   vpn_get_hy_port <vps>
vpn_get_hy_port() {
  local vps="${1:?vps}" p
  p=$(incus config get "$vps" user.vpsforge.vpn_hy_port 2>/dev/null || true)
  [ -n "$p" ] || p=$(vpn_get_port "$vps")
  echo "$p"
}
