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
    echo "1) Enable / Disable Auto Refresh   the dashboard updates by itself"
    echo "2) Change Refresh Interval   e.g. every 10 seconds"
    echo "3) Repair Connection   fixes SSH access and network of every VPS"
    echo "4) Update / Change Version   get the newest VPSForge, or go back to an older one"
    echo "5) Host Network Speed Configuration   e.g. 1000 = 1 Gbit/s"
    echo "6) Enable / Disable Auto Start on Login   open VPSForge automatically when you log in by SSH"
    echo "7) Uninstall VPSForge (remove everything, server returns to clean)"
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
        show_example "10  (the dashboard refreshes every 10 seconds)"
        read -r -p "Enter new refresh interval in seconds (min 2s) [Enter = $REFRESH_INTERVAL, 0=Back]: " new_interval
        [ "$new_interval" = "0" ] && continue
        new_interval="${new_interval:-$REFRESH_INTERVAL}"
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
        show_example "1000 = a 1 Gbit/s server connection (used to show the speed limits)"
        read -r -p "Enter total network speed of host in Mbit [Enter = $current_net_speed, 0=Back]: " new_speed
        [ "$new_speed" = "0" ] && continue
        new_speed="${new_speed:-$current_net_speed}"
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
      7)
        if vpsforge_uninstall; then
          printf "[?1049l"
          exit 0
        fi
        pause
        ;;
      0) return;;
      *) sleep 1;;
    esac
  done
}
