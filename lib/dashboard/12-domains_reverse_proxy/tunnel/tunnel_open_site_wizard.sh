#!/bin/bash
# Open a site that runs on YOUR computer to the internet through a VPS, with no router access:
# your computer connects out to the VPS (ssh -R) and the server forwards visitors into that tunnel.
tunnel_open_site_wizard() {
  TW_VPS=""; TW_IP=""; TW_TPORT=""; TW_LPORT=""; TW_DOMAIN=""; TW_EXTPORT=""

  clear
  echo "================================================================"
  echo "              OPEN A SITE FROM MY COMPUTER"
  echo "================================================================"
  echo "No router access needed: your computer connects OUT to a VPS, and"
  echo "the site on your computer becomes reachable from the internet."
  echo

  run_wizard tunnel_wizard_step_vps tunnel_wizard_step_ports tunnel_wizard_step_address \
             tunnel_wizard_step_confirm || return

  echo "Allowing tunnels on $TW_VPS..."
  if ! enable_vps_tunnel_access "$TW_VPS"; then
    echo "ERROR: could not enable tunnels inside $TW_VPS (is ssh installed there?). Nothing was changed on the server."
    pause; return
  fi

  if [ -n "$TW_DOMAIN" ]; then
    ensure_caddy_installed || { pause; return; }
    add_proxy_route "$TW_VPS" "$TW_IP" "$TW_DOMAIN" "" "$TW_TPORT" "http" || { pause; return; }
  else
    port_forward_apply_rule tcp 0.0.0.0 "$TW_EXTPORT" "$TW_IP" "$TW_TPORT"
    port_forward_append_rule_to_file "$PORT_FORWARD_RULES_FILE" tcp 0.0.0.0 "$TW_EXTPORT" "$TW_IP" "$TW_TPORT"
    save_iptables
    sync_vps_metadata "$TW_VPS"
  fi

  echo
  echo "DONE. Now connect from your computer."
  echo
  print_tunnel_commands "$(get_vps_user "$TW_VPS")" "${PUBLIC_IP:-SERVER-IP}" "$(get_vps_saved_port "$TW_VPS")" "$TW_TPORT" "$TW_LPORT"
  echo
  echo "Login: user '$(get_vps_user "$TW_VPS")', the VPS password (main menu 8 shows it)."
  if [ -n "$TW_DOMAIN" ]; then
    echo "At your domain provider create an  A  record:  $TW_DOMAIN  ->  ${PUBLIC_IP:-your server IP}"
    echo "Open:  https://$TW_DOMAIN"
  else
    echo "Open:  http://${PUBLIC_IP:-SERVER-IP}:$TW_EXTPORT"
    echo "Note: your cloud provider's firewall (Oracle: VCN security list, Google: VPC rule) must also allow TCP port $TW_EXTPORT."
  fi
  echo "To remove it later: 'My domains' (menu 12-2) or Port Forwarding (menu 11)."
  pause
}
