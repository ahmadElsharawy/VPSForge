#!/bin/bash
get_total_network_mbit() {
  local saved speed iface
  saved=$(cat /opt/vpsforge/network_speed_mbit 2>/dev/null || true)
  if [[ "$saved" =~ ^[0-9]+$ ]] && [ "$saved" -gt 0 ]; then echo "$saved"; return; fi
  iface=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
  speed=$(cat "/sys/class/net/$iface/speed" 2>/dev/null || true)
  if [[ "$speed" =~ ^[0-9]+$ ]] && [ "$speed" -gt 1000 ]; then
    echo "$speed"
  else
    echo 10000
  fi
}
