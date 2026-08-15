#!/bin/bash

settings_menu() {
  local c new_interval current_net_speed new_speed
  while :; do
    clear
    current_net_speed=$(get_total_network_mbit 2>/dev/null || echo 10000)
    echo "================================================"
    echo "                    SETTINGS"
    echo "================================================"
    echo
    echo "Auto Refresh: $([ "$AUTO_REFRESH" = "on" ] && echo ON || echo OFF)"
    echo "Refresh Interval: ${REFRESH_INTERVAL} seconds"
    echo "Auto Start on Login: $([ "${AUTO_START_ON_LOGIN:-off}" = "on" ] && echo ON || echo OFF)"
    echo "Host Network Speed: ${current_net_speed} Mbit"
    echo "Current Version: $VPSFORGE_VERSION"
    echo
    echo "0) Back"
    echo "1) Enable / Disable Auto Refresh"
    echo "2) Change Refresh Interval"
    echo "3) Repair Connection"
    echo "4) Update / Change Version"
    echo "5) Host Network Speed Configuration"
    echo "6) Enable / Disable Auto Start on Login"
    echo
    read -r -p "Choice [0=Back, Enter=1]: " c
    c="${c:-1}"

    case "$c" in
      1)
        if [ "$AUTO_REFRESH" = "on" ]; then
          AUTO_REFRESH="off"
        else
          AUTO_REFRESH="on"
        fi
        save_settings
        ;;
      2)
        read -r -p "Enter new refresh interval in seconds (min 2s) [Enter = 10]: " new_interval
        new_interval="${new_interval:-10}"
        if [[ "$new_interval" =~ ^[0-9]+$ ]] && [ "$new_interval" -ge 2 ]; then
          REFRESH_INTERVAL="$new_interval"
          save_settings
        else
          echo "Invalid interval. Must be a number >= 2."
          sleep 2
        fi
        ;;
      3)
        repair_connection_menu
        pause
        ;;
      4)
        update_menu
        ;;
      5)
        read -r -p "Enter total network speed of host in Mbit (e.g. 1000, 10000): " new_speed
        if [[ "$new_speed" =~ ^[0-9]+$ ]] && [ "$new_speed" -ge 1 ]; then
          set_total_network_mbit "$new_speed"
          echo "Host Network Speed updated to ${new_speed} Mbit."
          sleep 2
        else
          echo "Invalid speed."
          sleep 2
        fi
        ;;
      6)
        if [ "${AUTO_START_ON_LOGIN:-off}" = "on" ]; then
          AUTO_START_ON_LOGIN="off"
          echo "Auto Start on Login: DISABLED"
        else
          AUTO_START_ON_LOGIN="on"
          echo "Auto Start on Login: ENABLED"
        fi
        save_settings
        sleep 1
        ;;
      0) return;;
      *) sleep 1;;
    esac
  done
}
