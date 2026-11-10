#!/bin/bash
# Port Xray listens on inside the VPS: the same number as the public port, so the link and
# the server's forward always match (VPN_INNER_PORT when the VPS has no VPN yet).
#   vpn_inner_port <vps>
vpn_inner_port() {
  local p
  p=$(vpn_get_port "${1:?vps}")
  echo "${p:-$VPN_INNER_PORT}"
}
