#!/bin/bash
# Interactive action: pick a VPN and confirm removing it from the VPS.
_vpn_action_remove_vpn() {
  local answer
  if vpn_pick_vpn; then
    read -r -p "Remove the VPN from $VPN_VPS? All its devices stop working. [y/N]: " answer </dev/tty
    if [[ "${answer,,}" =~ ^y ]]; then vpn_remove "$VPN_VPS" && echo "VPN removed from $VPN_VPS."; fi
  fi
  pause
}
