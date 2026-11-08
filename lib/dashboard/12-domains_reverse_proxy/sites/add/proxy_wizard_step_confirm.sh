#!/bin/bash
# Wizard step 5 of 5: show the summary and ask for confirmation.
proxy_wizard_step_confirm() {
  local answer
  echo
  echo "Step 5 of 5 - Confirm"
  if proxy_route_exists "$PW_DOMAIN" "$PW_PATH"; then
    return 1
  fi
  echo "Checking how the app talks (http or https)..."
  PW_SCHEME=$(detect_backend_scheme "$PW_IP" "$PW_PORT")
  echo "----------------------------------------------------------------"
  echo "  https://$PW_DOMAIN${PW_PATH:+$PW_PATH}  ->  $PW_VPS  ($PW_SCHEME://$PW_IP:$PW_PORT)"
  echo "----------------------------------------------------------------"
  read -r -p "Create it? [Y/n, 0=Back]: " answer </dev/tty
  [ "$answer" = "0" ] && return "$WIZARD_BACK"
  [[ "${answer,,}" =~ ^n ]] && { echo "Cancelled."; return 1; }
  return 0
}
