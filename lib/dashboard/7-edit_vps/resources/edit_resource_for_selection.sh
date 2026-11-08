#!/bin/bash
# Change one resource (ram, cpu, disk, network or traffic) for the selected VPSs.
# One VPS: ask once. Several: each separately, or one answer applied to all.
edit_resource_for_selection() {
  local resource="${1:?resource}" n first=1 mode="" value="" rx="" tx=""
  edit_ask_scope || return

  for n in "${SELECTED_VPS[@]}"; do
    if [ "$EDIT_SCOPE" = "2" ] && [ "$first" -eq 0 ]; then
      :  # same answer as the first VPS
    else
      case "$resource" in
        ram)     ask_ram_mode "$n"     || { [ "$EDIT_SCOPE" = "2" ] && return; continue; }; mode="$RAM_MODE_RESULT";     value="${RAM_VALUE_RESULT:-}";;
        cpu)     ask_cpu_mode "$n"     || { [ "$EDIT_SCOPE" = "2" ] && return; continue; }; mode="$CPU_MODE_RESULT";     value="${CPU_VALUE_RESULT:-}";;
        disk)    ask_disk_mode "$n"    || { [ "$EDIT_SCOPE" = "2" ] && return; continue; }; mode="$DISK_MODE_RESULT";    value="${DISK_VALUE_RESULT:-}";;
        network) ask_network_mode "$n" || { [ "$EDIT_SCOPE" = "2" ] && return; continue; }; mode="$NETWORK_MODE_RESULT"; value="${NETWORK_VALUE_RESULT:-}";;
        traffic) ask_traffic_mode "$n" || { [ "$EDIT_SCOPE" = "2" ] && return; continue; }; mode="$TRAFFIC_MODE_RESULT"; rx="$TRAFFIC_RX_RESULT"; tx="$TRAFFIC_TX_RESULT";;
        *) echo "Unknown resource: $resource"; return 1;;
      esac
    fi
    first=0
    case "$resource" in
      ram)     set_ram_mode_for_vps "$n" "$mode" "$value";;
      cpu)     set_cpu_mode_for_vps "$n" "$mode" "$value";;
      disk)    set_disk_mode_for_vps "$n" "$mode" "$value";;
      network) set_network_mode_for_vps "$n" "$mode" "$value";;
      traffic) set_traffic_mode_for_vps "$n" "$mode" "$rx" "$tx";;
    esac
  done
}
