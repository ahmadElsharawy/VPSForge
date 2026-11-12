#!/bin/bash
# Create-VPN wizard step 1 of 4: which VPS carries the VPN. Warns when its speed is limited.
vpn_wizard_step_vps() {
  local limit
  echo "Step 1 of 4 - Which VPS will carry the VPN?"
  show_example "a running VPS; your devices connect to it and use its internet"
  select_vps || return "$WIZARD_BACK"
  VW_VPS="$SELECTED"
  if ! is_vps_running "$VW_VPS" || [ -z "$(get_ip "$VW_VPS")" ]; then
    echo "ERROR: '$VW_VPS' must be running and have an IP address. Start it first (main menu 3)."
    return 1
  fi
  if [ -n "$(vpn_get_port "$VW_VPS")" ]; then
    echo "ERROR: $VW_VPS already has a VPN. Use 'Add a device' instead."
    return 1
  fi
  limit=$(get_vps_network_limit_mbit "$VW_VPS")
  if [ -n "$limit" ]; then
    echo "NOTE: $VW_VPS is limited to $limit Mbit, so the VPN cannot be faster than that."
    echo "      For full speed: Edit VPS (menu 7) > Change Network Speed > Unlimited."
  fi
  return 0
}
