#!/bin/bash
# Wizard step 1 of 5: which VPS runs the app.
proxy_wizard_step_vps() {
  echo "Step 1 of 5 - Which VPS runs the app?"
  show_example "the VPS where your web app (Node, PHP, nginx, 3x-ui...) is installed"
  select_vps || return "$WIZARD_BACK"
  PW_VPS="$SELECTED"
  PW_IP=$(get_ip "$PW_VPS")
  if [ -z "$PW_IP" ] || ! is_vps_running "$PW_VPS"; then
    echo "ERROR: '$PW_VPS' must be running and have an IP address. Start it first (main menu 3)."
    return 1
  fi
  return 0
}
