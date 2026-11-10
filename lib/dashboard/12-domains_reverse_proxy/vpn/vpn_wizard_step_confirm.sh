#!/bin/bash
# Create-VPN wizard step 3 of 3: confirm.
vpn_wizard_step_confirm() {
  local answer
  echo
  echo "Step 3 of 3 - Confirm"
  echo "  VPS:          $VW_VPS"
  echo "  Server port:  ${PUBLIC_IP:-SERVER}:$VW_PORT (TCP), QR page on $((VW_PORT + 1))"
  echo "  Type:         Xray VLESS + Reality (fast, looks like normal HTTPS)"
  read -r -p "Create the VPN? [Y/n, 0=Back]: " answer </dev/tty
  [ "$answer" = "0" ] && return "$WIZARD_BACK"
  [[ "${answer,,}" =~ ^n ]] && return 1
  return 0
}
