#!/bin/bash
# Wizard step 4 of 4: summary and confirmation.
tunnel_wizard_step_confirm() {
  local answer target
  echo
  echo "Step 4 of 4 - Confirm"
  if [ -n "$TW_DOMAIN" ]; then target="https://$TW_DOMAIN"; else target="http://${PUBLIC_IP:-SERVER-IP}:$TW_EXTPORT"; fi
  echo "----------------------------------------------------------------"
  echo "  $target  ->  $TW_VPS (port $TW_TPORT)  ->  tunnel  ->  your computer (port $TW_LPORT)"
  echo "----------------------------------------------------------------"
  read -r -p "Create it? [Y/n, 0=Back]: " answer </dev/tty
  [ "$answer" = "0" ] && return "$WIZARD_BACK"
  [[ "${answer,,}" =~ ^n ]] && { echo "Cancelled."; return 1; }
  return 0
}
