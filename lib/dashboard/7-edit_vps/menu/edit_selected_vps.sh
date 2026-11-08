#!/bin/bash
# The one Edit menu, for the VPSs in SELECTED_VPS (one, several or all).
# With more than one VPS, every option asks: each VPS separately, or the same for all.
edit_selected_vps() {
  local choice label
  while :; do
    if [ "${#SELECTED_VPS[@]}" -eq 1 ]; then
      label="${SELECTED_VPS[0]}"
    else
      label="${#SELECTED_VPS[@]} VPSs: ${SELECTED_VPS[*]}"
    fi
    echo
    echo "Editing: $label"
    echo "0) Back"
    echo "1) Change RAM                  e.g. 512 MB for a small site"
    echo "2) Change CPU                  e.g. 1 core"
    echo "3) Change Disk                 e.g. 10 GB"
    echo "4) Change Network Speed        e.g. 100 Mbit"
    echo "5) Change Traffic Data Limit (Download/Upload Quota)   e.g. 100 GB per month"
    echo "6) Change SSH Port             e.g. 2222"
    echo "7) Change Username             e.g. admin"
    echo "8) Change Password"
    echo "9) Rename VPS Container      e.g. web1"
    echo "10) Change Internal IP       e.g. 10.x.x.150"
    echo "11) Swap IP & Port with another VPS   (exchange addresses of two VPSs)"
    echo "12) Reinstall / Change OS Image   e.g. switch to Alpine (tiny) or Debian"
    read -r -p "Choice [0=Back, Enter=1]: " choice
    choice="${choice:-1}"
    case "$choice" in
      1) edit_resource_for_selection ram;;
      2) edit_resource_for_selection cpu;;
      3) edit_resource_for_selection disk;;
      4) edit_resource_for_selection network;;
      5) edit_resource_for_selection traffic;;
      6) edit_each_selected edit_change_port;;
      7) edit_text_for_selection username;;
      8) edit_text_for_selection password;;
      9) edit_rename_selection;;
      10) edit_each_selected edit_change_ip;;
      11) edit_swap_selection;;
      12) edit_os_for_selection;;
      0) return;;
      *) echo "Invalid choice.";;
    esac
  done
}
