#!/bin/bash
# Wizard step 3 of 4: how people reach the site - a domain (HTTPS) or the server IP and a port.
tunnel_wizard_step_address() {
  local domain extport
  echo
  echo "Step 3 of 4 - Public address"
  show_example "test.mydomain.com   (HTTPS, automatic)   or leave empty to use http://${PUBLIC_IP:-SERVER-IP}:PORT"
  read -r -p "Domain [Enter=none, 0=Back]: " domain </dev/tty
  [ "$domain" = "0" ] && return "$WIZARD_BACK"
  domain="${domain,,}"

  if [ -n "$domain" ]; then
    if ! [[ "$domain" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?\.[a-z]{2,}$ ]]; then
      echo "ERROR: '$domain' is not a valid domain name."; return 1
    fi
    if proxy_route_exists "$domain" ""; then
      echo "ERROR: '$domain' is already used (see 'My domains')."; return 1
    fi
    TW_DOMAIN="$domain"; TW_EXTPORT=""
    return 0
  fi

  TW_DOMAIN=""
  read -r -p "Public port on the server [Enter=$TW_TPORT, 0=Back]: " extport </dev/tty
  [ "$extport" = "0" ] && return "$WIZARD_BACK"
  extport="${extport:-$TW_TPORT}"
  if ! [[ "$extport" =~ ^[0-9]+$ ]] || [ "$extport" -lt 1024 ] || [ "$extport" -gt 65535 ]; then
    echo "ERROR: choose a port between 1024 and 65535."; return 1
  fi
  if awk -F'|' -v p="$extport" '$3 == p { f = 1 } END { exit !f }' "$PORT_FORWARD_RULES_FILE" 2>/dev/null; then
    echo "ERROR: port $extport is already forwarded to another VPS."; return 1
  fi
  if ! port_forward_host_conflict "$extport" tcp; then
    return 1
  fi
  TW_EXTPORT="$extport"
  return 0
}
