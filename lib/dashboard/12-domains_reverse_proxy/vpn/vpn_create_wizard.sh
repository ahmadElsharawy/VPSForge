#!/bin/bash
# Create a VPN on a VPS, then offer to add the first device right away.
vpn_create_wizard() {
  VW_VPS=""; VW_PORT=""; VW_SNI=""; VW_TLS_SNI=""; VW_HY_SNI=""
  clear
  echo "================================================================"
  echo "                        CREATE A VPN"
  echo "================================================================"
  run_wizard vpn_wizard_step_vps vpn_wizard_step_port vpn_wizard_step_sni vpn_wizard_step_confirm || return
  if ! vpn_create "$VW_VPS" "$VW_PORT" "$VW_SNI" "$VW_TLS_SNI" "$VW_HY_SNI"; then
    echo "ERROR: the VPN could not be created. Nothing was left on the server."
    pause; return
  fi
  echo
  echo "DONE. VPN is running on $VW_VPS (port $VW_PORT TCP)."
  echo "Remember: open TCP $VW_PORT, $((VW_PORT + 1)) and $((VW_PORT + VPN_TLS_PORT_OFFSET)), and UDP $(vpn_get_hy_port "$VW_VPS") in your cloud firewall."
  echo
  local answer
  read -r -p "Add your first device now? [Y/n]: " answer </dev/tty
  [[ "${answer,,}" =~ ^n ]] && return
  VPN_VPS="$VW_VPS"
  vpn_add_device_wizard "$VW_VPS"
}
