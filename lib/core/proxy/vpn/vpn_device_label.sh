#!/bin/bash
# Name shown in the VPN app for one device (days and GB left), see _vpn_label_from.
#   vpn_device_label <vps> <device>
vpn_device_label() {
  local vps="${1:?vps}" name="${2:?device}" line used limit expires
  line=$(vpn_list_devices "$vps" | awk -F'|' -v n="$name" '$1 == n { print; exit }')
  IFS='|' read -r _ _ _ _ used limit expires _ <<< "$line"
  _vpn_label_from "$vps" "$used" "$limit" "$expires"
}
