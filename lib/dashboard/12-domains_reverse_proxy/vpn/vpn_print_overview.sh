#!/bin/bash
# Print every VPN and its devices: connected or last seen, data used / limit, days left.
vpn_print_overview() {
  local row vps port line dev_name dev_ip dev_mac ago used limit expires state seen data days any=0 now
  now=$(date +%s)
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    any=1
    vps="${row%%|*}"; port="${row#*|}"
    echo "VPN on $vps   ->  ${PUBLIC_IP:-SERVER}:$port (TCP)"
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      IFS='|' read -r dev_name dev_ip dev_mac ago used limit expires state <<< "$line"
      if [ -z "$ago" ]; then seen="never connected"
      elif [ "$ago" -lt 180 ]; then seen="CONNECTED"
      elif [ "$ago" -lt 3600 ]; then seen="seen $((ago / 60)) min ago"
      else seen="seen $((ago / 3600)) h ago"; fi
      data=$(awk -v b="${used:-0}" 'BEGIN { printf "%.1f", b / 1073741824 }')
      if [ "${limit:-0}" -gt 0 ]; then data="$data/${limit} GB"; else data="$data GB/unlimited"; fi
      if [ "${expires:-0}" -gt 0 ]; then
        if [ "$expires" -gt "$now" ]; then days="$(( (expires - now + 86399) / 86400 )) days left"; else days="time is over"; fi
      else
        days="no end date"
      fi
      case "$state" in
        off-data) seen="OFF: data limit reached";;
        off-time) seen="OFF: days are over";;
      esac
      printf '    %-18s %-20s %-15s %s\n' "$dev_name" "$data" "$days" "$seen"
    done < <(vpn_list_devices "$vps")
  done < <(vpn_all_vps)
  [ "$any" -eq 1 ] || echo "No VPN yet."
}
