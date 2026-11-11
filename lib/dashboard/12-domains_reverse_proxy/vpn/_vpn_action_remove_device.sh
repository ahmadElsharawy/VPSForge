#!/bin/bash
# Interactive action: pick a VPN device and confirm its removal.
_vpn_action_remove_device() {
  local answer
  if vpn_pick_vpn && vpn_pick_device "$VPN_VPS" "Device to remove"; then
    read -r -p "Remove '$VPN_DEVICE' from the VPN of $VPN_VPS? [y/N]: " answer </dev/tty
    if [[ "${answer,,}" =~ ^y ]]; then vpn_remove_device "$VPN_VPS" "$VPN_DEVICE" && echo "Removed."; fi
  fi
  pause
}
