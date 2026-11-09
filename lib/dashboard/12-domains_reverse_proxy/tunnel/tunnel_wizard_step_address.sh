#!/bin/bash
# Wizard step 3 of 4: how people reach the site - a domain (HTTPS) or the server IP and a port.
tunnel_wizard_step_address() {
  local domain extport answer current=""
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
  extport="${TW_EDIT_EXT:-$TW_TPORT}"
  read -r -p "Public port on the server [Enter=$extport, 0=Back]: " answer </dev/tty
  [ "$answer" = "0" ] && return "$WIZARD_BACK"
  extport="${answer:-$extport}"
  if ! [[ "$extport" =~ ^[0-9]+$ ]] || [ "$extport" -lt 1024 ] || [ "$extport" -gt 65535 ]; then
    echo "ERROR: choose a port between 1024 and 65535."; return 1
  fi
  if [ "$extport" != "$TW_EDIT_EXT" ]; then
    if awk -F'|' -v p="$extport" '$3 == p { f = 1 } END { exit !f }' "$PORT_FORWARD_RULES_FILE" 2>/dev/null; then
      echo "ERROR: port $extport is already forwarded to another VPS."; return 1
    fi
    port_forward_host_conflict "$extport" tcp || return 1
  fi
  TW_EXTPORT="$extport"
  return 0
}
