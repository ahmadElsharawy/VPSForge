#!/bin/bash
# Prompts the user for the host network speed in Mbit and updates configuration.
_settings_prompt_network_speed() {
  local current_net_speed="$1"
  local new_speed
  show_example "1000 = a 1 Gbit/s server connection (used to show the speed limits)"
  read -r -p "Enter total network speed of host in Mbit [Enter = $current_net_speed, 0=Back]: " new_speed
  [ "$new_speed" = "0" ] && return
  new_speed="${new_speed:-$current_net_speed}"
  if [[ "$new_speed" =~ ^[0-9]+$ ]] && [ "$new_speed" -ge 1 ]; then
    set_total_network_mbit "$new_speed"
    echo "Host Network Speed updated to ${new_speed} Mbit."
    sleep 2
  else
    echo "Invalid speed."
    sleep 2
  fi
}
