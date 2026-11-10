#!/bin/bash
# Print the public UDP port of the VPN on a VPS (empty when the VPS has no VPN).
# It is kept in the VPS's own Incus metadata, so it is removed together with the VPS.
#   vpn_get_port <vps>
vpn_get_port() {
  incus config get "${1:?vps}" user.vpsforge.vpn 2>/dev/null || true
}
