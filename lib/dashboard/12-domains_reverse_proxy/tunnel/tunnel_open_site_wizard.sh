#!/bin/bash
# Add a tunnel: open a site that runs on YOUR computer to the internet through a VPS, with no router access.
# Your computer connects out to the VPS (ssh -R) and the server forwards visitors into that tunnel.
# A server-port tunnel appears in Port Forward (menu 11) automatically; a domain tunnel in "My domains".
tunnel_open_site_wizard() {
  TW_VPS=""; TW_IP=""; TW_TPORT=""; TW_LPORT=""; TW_DOMAIN=""; TW_EXTPORT=""
  TW_EDIT_TPORT=""; TW_EDIT_EXT=""; TW_EDIT_DOMAIN=""

  clear
  echo "================================================================"
  echo "                      ADD A TUNNEL"
  echo "================================================================"
  echo "Your computer connects OUT to a VPS, and the site on your computer"
  echo "becomes reachable from the internet. No router access needed."
  echo

  run_wizard tunnel_wizard_step_vps tunnel_wizard_step_ports tunnel_wizard_step_address \
             tunnel_wizard_step_confirm || return

  echo "Creating the tunnel..."
  tunnel_access_remove "$TW_VPS" "$TW_TPORT"   # leftovers of an older tunnel on this port must not come back
  if ! tunnel_create "$TW_VPS" "$TW_TPORT" "$TW_LPORT" "$TW_EXTPORT" "$TW_DOMAIN"; then
    echo "ERROR: the tunnel could not be created. Nothing was changed on the server."
    pause; return
  fi

  echo
  echo "DONE. Now connect from your computer."
  echo
  tunnel_show_connect "$TW_VPS" "$TW_TPORT"
  echo
  echo "Manage it any time: Sites from my computer > My tunnels (start / stop / edit / delete)."
  pause
}
