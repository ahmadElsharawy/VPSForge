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
