#!/bin/bash
# Print the Reality SNI (the HTTPS site the VPN looks like) of a VPS's VPN.
# VPNs made before the SNI could be chosen have none saved: they keep the old default.
#   vpn_get_sni <vps>
vpn_get_sni() {
  local sni
  sni=$(incus config get "${1:?vps}" user.vpsforge.vpn_sni 2>/dev/null || true)
  echo "${sni:-$VPN_SNI}"
}
