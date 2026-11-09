#!/bin/bash
# Wizard step 1 of 4: which VPS carries the tunnel.
tunnel_wizard_step_vps() {
  echo "Step 1 of 4 - Which VPS will carry the tunnel?"
  show_example "any running VPS; your computer connects to it and the site appears on the internet"
  select_vps || return "$WIZARD_BACK"
  TW_VPS="$SELECTED"
  TW_IP=$(get_ip "$TW_VPS")
  if [ -z "$TW_IP" ] || ! is_vps_running "$TW_VPS"; then
    echo "ERROR: '$TW_VPS' must be running and have an IP address. Start it first (main menu 3)."
    return 1
  fi
  return 0
}
