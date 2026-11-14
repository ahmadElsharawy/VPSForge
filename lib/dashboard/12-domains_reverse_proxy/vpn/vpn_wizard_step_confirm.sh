#!/bin/bash
# Create-VPN wizard step 4 of 4: confirm.
vpn_wizard_step_confirm() {
  local answer
  echo
  echo "Step 4 of 4 - Confirm"
  echo "  VPS:          $VW_VPS"
  echo "  Server port:  ${PUBLIC_IP:-SERVER}:$VW_PORT (TCP Reality + UDP Hysteria2), VLESS+TLS on $((VW_PORT + VPN_TLS_PORT_OFFSET)) (TCP), QR page on $((VW_PORT + 1))"
  echo "  Looks like:   https://$VW_SNI (Reality SNI)"
  echo "  Type:         3 protocols per device: VLESS+Reality, VLESS+TLS and Hysteria2"
  read -r -p "Create the VPN? [Y/n, 0=Back]: " answer </dev/tty
  [ "$answer" = "0" ] && return "$WIZARD_BACK"
  [[ "${answer,,}" =~ ^n ]] && return 1
  return 0
}
