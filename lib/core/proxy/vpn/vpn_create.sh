#!/bin/bash
# Create a VPN (Xray, VLESS + Reality) on a VPS, reachable on <public_tcp_port> of this server.
# Guarded: if it fails or is stopped, everything it added is removed again.
#   vpn_create <vps> <public_tcp_port> [sni]
vpn_create() {
  local vps="${1:?vps}" ext="${2:?public port}" sni="${3:-$VPN_SNI}"
  # Checked BEFORE the guard: if this VPS already has a VPN, the guard's cleanup
  # (vpn_remove) must never run, or it would delete the VPN that was already there.
  if [ -n "$(vpn_get_port "$vps")" ]; then
    echo "ERROR: $vps already has a VPN."
    return 1
  fi
  run_guarded "vpn_remove $vps" _vpn_create_steps "$vps" "$ext" "$sni"
}
