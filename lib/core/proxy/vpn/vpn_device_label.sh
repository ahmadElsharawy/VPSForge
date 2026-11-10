#!/bin/bash
# Print the name of a device's VPN link (shown by the app):  <public_ip>-<vps>-<days>-<GB>
# e.g. 193.122.84.156-vps3-30d-50GB   or   193.122.84.156-vps3-unl-unl  (unl = unlimited)
# <days> = days left now (rounded up), <GB> = the data limit.
#   vpn_device_label <vps> <device>
vpn_device_label() {
  local vps="${1:?vps}" name="${2:?device}" line limit expires days gb now
  line=$(vpn_list_devices "$vps" | awk -F'|' -v n="$name" '$1 == n { print; exit }')
  IFS='|' read -r _ _ _ _ _ limit expires _ <<< "$line"
  now=$(date +%s)
  if [ "${expires:-0}" -gt 0 ]; then
    if [ "$expires" -gt "$now" ]; then days="$(( (expires - now + 86399) / 86400 ))d"; else days="0d"; fi
  else
    days="unl"
  fi
  if [ "${limit:-0}" -gt 0 ]; then gb="${limit}GB"; else gb="unl"; fi
  echo "${PUBLIC_IP:-server}-${vps}-${days}-${gb}"
}
