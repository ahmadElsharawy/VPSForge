#!/bin/bash

# Displays and handles the main settings menu options.
settings_menu() {
  local choice current_net_speed
  while :; do
    clear
    current_net_speed=$(get_total_network_mbit 2>/dev/null || echo 10000)
    _settings_menu_print "$current_net_speed"
    read -r -p "Choice [0=Back, Enter=1]: " choice
    choice="${choice:-1}"

    case "$choice" in
      1) _settings_toggle_auto_refresh;;
      2) _settings_prompt_interval;;
      3) repair_connection_menu; pause;;
      4) update_menu;;
      5) _settings_prompt_network_speed "$current_net_speed";;
      6) _settings_toggle_auto_start;;
      7)
        if vpsforge_uninstall; then
          printf " [?1049l"
          exit 0
        fi
        pause
        ;;
      0) return;;
      *) sleep 1;;
    esac
  done
}
