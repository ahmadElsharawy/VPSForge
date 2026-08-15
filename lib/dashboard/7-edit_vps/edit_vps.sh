#!/bin/bash
# VPSForge v1.0.0 — Edit VPS menu dispatcher.

edit_vps_menu() {
  ask_vps_selection || return
  if [ "${#SELECTED_VPS[@]}" -eq 1 ]; then
    edit_single_vps "${SELECTED_VPS[0]}"
  else
    edit_multiple_vps
  fi
}

edit_single_vps() {
  local name="$1" c
  while :; do
    echo
    echo "0) Back"
    echo "1) Change RAM"
    echo "2) Change CPU"
    echo "3) Change Disk"
    echo "4) Change Network Speed"
    echo "5) Change Traffic Data Limit (Download/Upload Quota)"
    echo "6) Change SSH Port"
    echo "7) Change Username"
    echo "8) Change Password"
    echo "9) Rename VPS Container"
    echo "10) Change Internal IP"
    echo "11) Swap IP & Port with another VPS"
    echo "12) Reinstall / Change OS Image"
    read -r -p "Choice [0=Back, Enter=1]: " c
    c="${c:-1}"
    case "$c" in
      1) edit_change_ram "$name";;
      2) edit_change_cpu "$name";;
      3) edit_change_disk "$name";;
      4) edit_change_network "$name";;
      5) edit_change_traffic "$name";;
      6) edit_change_port "$name";;
      7) edit_change_username "$name";;
      8) edit_change_password "$name";;
      9) rename_vps_container "$name";;
      10) edit_change_ip "$name";;
      11) edit_swap_ip "$name";;
      12) edit_reinstall_image "$name";;
      0) return;;
    esac
  done
}

edit_multiple_vps() {
  local c n sm sv tm trx ttx
  while :; do
    echo
    echo "0) Back"
    echo "1) Change RAM"
    echo "2) Change CPU"
    echo "3) Change Disk"
    echo "4) Change Network Speed"
    echo "5) Change Traffic Data Limit (Download/Upload Quota)"
    echo "6) Change Username"
    echo "7) Change Password"
    read -r -p "Choice [0=Back, Enter=1]: " c
    c="${c:-1}"
    case "$c" in
      1|2|3|4|5)
        local mode
        echo "0) Back"
        echo "1) Configure each VPS individually (Default)"
        echo "2) Same setting for all selected VPS"
        read -r -p "Choice [0=Back, Enter=1]: " mode
        mode="${mode:-1}"
        [ "$mode" = "0" ] && continue
        for n in "${SELECTED_VPS[@]}"; do
          if [ "$mode" = "2" ] && [ "$n" != "${SELECTED_VPS[0]}" ]; then
            :
          else
            case "$c" in
              1) ask_ram_mode "$n" || continue; sm="$RAM_MODE_RESULT"; sv="$RAM_VALUE_RESULT";;
              2) ask_cpu_mode "$n" || continue; sm="$CPU_MODE_RESULT"; sv="$CPU_VALUE_RESULT";;
              3) ask_disk_mode "$n" || continue; sm="$DISK_MODE_RESULT"; sv="$DISK_VALUE_RESULT";;
              4) ask_network_mode "$n" || continue; sm="$NETWORK_MODE_RESULT"; sv="$NETWORK_VALUE_RESULT";;
              5) ask_traffic_mode "$n" || continue; tm="$TRAFFIC_MODE_RESULT"; trx="$TRAFFIC_RX_RESULT"; ttx="$TRAFFIC_TX_RESULT";;
            esac
          fi
          case "$c" in
            1) set_ram_mode_for_vps "$n" "$sm" "$sv";;
            2) set_cpu_mode_for_vps "$n" "$sm" "$sv";;
            3) set_disk_mode_for_vps "$n" "$sm" "$sv";;
            4) set_network_mode_for_vps "$n" "$sm" "$sv";;
            5) set_traffic_mode_for_vps "$n" "$tm" "$trx" "$ttx";;
          esac
        done
        ;;
      6) local value; read -r -p "New username for all: " value; for n in "${SELECTED_VPS[@]}"; do change_vps_username "$n" "$value"; done;;
      7) local value; read -r -s -p "New password for all: " value; echo; for n in "${SELECTED_VPS[@]}"; do change_vps_password "$n" "$value"; done;;
      0) return;;
    esac
  done
}
