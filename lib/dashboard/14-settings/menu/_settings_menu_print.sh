#!/bin/bash
# Renders the settings menu options and current configuration values.
_settings_menu_print() {
  local current_net_speed="$1"
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
}
