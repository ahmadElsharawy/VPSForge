#!/bin/bash
# Name shown in the VPN app for a device: SERVER-VPS-<days left>-<GB left>, "unl" when there is no end
# date or data limit. Example: 1.2.3.4-vps1-29d-47GB. Pure: no incus call.
#   _vpn_label_from <vps> <used_bytes> <limit_gb> <expires_epoch>
_vpn_label_from() {
  local vps="${1:?vps}" used="${2:-0}" limit="${3:-0}" expires="${4:-0}" now days gb
  now=$(date +%s)
  if [ "${expires:-0}" -gt 0 ]; then
    if [ "$expires" -gt "$now" ]; then days="$(( (expires - now + 86399) / 86400 ))d"; else days="0d"; fi
  else
    days="unl"
  fi
  if [ "${limit:-0}" -gt 0 ]; then
    # GB left: whole numbers from 10 GB up, one decimal below (9.4GB)
    gb=$(awk -v l="$limit" -v u="${used:-0}" 'BEGIN { x = l - u / 1073741824; if (x < 0) x = 0
      if (x >= 10 || x == int(x)) printf "%dGB", x; else printf "%.1fGB", x }')
  else
    gb="unl"
  fi
  echo "${PUBLIC_IP:-server}-${vps}-${days}-${gb}"
}
