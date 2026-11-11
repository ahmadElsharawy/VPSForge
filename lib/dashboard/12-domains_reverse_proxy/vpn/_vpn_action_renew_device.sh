#!/bin/bash
# Interactive action: pick a VPN device, enter new limits, and renew it.
_vpn_action_renew_device() {
  if vpn_pick_vpn && vpn_pick_device "$VPN_VPS" "Device to renew"; then
    VW_VPS="$VPN_VPS"
    if vpn_wizard_step_device_limits; then
      vpn_set_device_limits "$VPN_VPS" "$VPN_DEVICE" "$VW_GB" "$VW_DAYS" && echo "Renewed: '$VPN_DEVICE' works again."
    fi
  fi
  pause
}
