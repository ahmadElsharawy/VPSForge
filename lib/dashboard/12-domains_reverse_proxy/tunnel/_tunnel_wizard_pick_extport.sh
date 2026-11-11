#!/bin/bash
# Prompt and validate public host port for a tunnel without a domain.
#   _tunnel_wizard_pick_extport
_tunnel_wizard_pick_extport() {
  local extport="${TW_EDIT_EXT:-$TW_TPORT}" answer
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
