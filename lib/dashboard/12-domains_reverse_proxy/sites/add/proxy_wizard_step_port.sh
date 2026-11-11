#!/bin/bash
# Wizard step 2 of 5: which port the app uses inside the VPS.
proxy_wizard_step_port() {
  local choice default_port=80 port last_port
  last_port=$(pref_get proxy_port "")
  local -a ports=()

  echo
  echo "Step 2 of 5 - Which port does the app use inside $PW_VPS?"
  show_example "3000 for a Node app, 80 for nginx/Apache, 54321 for a panel"
  mapfile -t ports < <(list_vps_listening_ports "$PW_VPS")
  if [ "${#ports[@]}" -gt 0 ]; then
    default_port="${ports[0]}"
    for port in "${ports[@]}"; do [ "$port" = "80" ] && default_port=80; done
    for port in "${ports[@]}"; do [ "$port" = "$last_port" ] && default_port="$last_port"; done
    _proxy_print_detected_ports "$default_port" "${ports[@]}"
    read -r -p "Pick a number, or type any port [Enter=$default_port, 0=Back]: " choice </dev/tty
  else
    echo "Nothing is listening yet (you can still set it up now and start the app later)."
    [ -n "$last_port" ] && default_port="$last_port"
    read -r -p "Port of your app [Enter=$default_port, 0=Back]: " choice </dev/tty
  fi

  [ "$choice" = "0" ] && return "$WIZARD_BACK"
  PW_PORT="$default_port"
  if [[ "$choice" =~ ^[0-9]+$ ]]; then
    if [ "$choice" -ge 1 ] && [ "$choice" -le "${#ports[@]}" ]; then
      PW_PORT="${ports[$((choice - 1))]}"
    elif [ "$choice" -ge 1 ] && [ "$choice" -le 65535 ]; then
      PW_PORT="$choice"
    else
      echo "Invalid port."; return 1
    fi
  elif [ -n "$choice" ]; then
    echo "Invalid choice."; return 1
  fi
  pref_set proxy_port "$PW_PORT"
  return 0
}
