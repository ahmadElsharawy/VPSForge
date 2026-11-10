#!/bin/bash
# Add a device to a VPN, with a data limit and days (or unlimited), then show how to connect it (QR / file / link).
#   vpn_add_device_wizard [vps]
vpn_add_device_wizard() {
  local vps="${1:-}"
  if [ -z "$vps" ]; then vpn_pick_vpn || { pause; return; }; vps="$VPN_VPS"; fi
  VW_VPS="$vps"; VW_DEVICE=""; VW_GB=0; VW_DAYS=0
  echo
  echo "Add a device to the VPN of $vps"
  run_wizard vpn_wizard_step_device_name vpn_wizard_step_device_limits || return
  if ! vpn_add_device "$vps" "$VW_DEVICE" "$VW_GB" "$VW_DAYS"; then
    pause; return
  fi
  echo "Device '$VW_DEVICE' added."
  vpn_show_device "$vps" "$VW_DEVICE"
}
