#!/bin/bash
# Wizard step 3 of 4: how people reach the site - a domain (HTTPS) or the server IP and a port.
tunnel_wizard_step_address() {
  local domain current=""
  echo
  echo "Step 3 of 4 - Public address"
  show_example "test.mydomain.com   (HTTPS, automatic)   or leave empty to use http://${PUBLIC_IP:-SERVER-IP}:PORT"
  [ -n "$TW_EDIT_DOMAIN" ] && current="$TW_EDIT_DOMAIN"
  read -r -p "Domain [Enter=${current:-none}${current:+, -=no domain}, 0=Back]: " domain </dev/tty
  [ "$domain" = "0" ] && return "$WIZARD_BACK"
  domain="${domain,,}"
  if [ "$domain" = "-" ]; then domain=""; elif [ -z "$domain" ]; then domain="$current"; fi

  if [ -n "$domain" ]; then
    if ! [[ "$domain" =~ ^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$ ]]; then
      echo "ERROR: '$domain' is not a valid domain name."; return 1
    fi
    if [ "$domain" != "$TW_EDIT_DOMAIN" ] && proxy_route_exists "$domain" ""; then
      echo "ERROR: '$domain' is already used (see 'My domains')."; return 1
    fi
    TW_DOMAIN="$domain"; TW_EXTPORT=""
    return 0
  fi

  TW_DOMAIN=""
  _tunnel_wizard_pick_extport
}
