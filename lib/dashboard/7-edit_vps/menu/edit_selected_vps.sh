#!/bin/bash
# Displays the editing menu for selected VPS instances and routes to specific editors.

edit_selected_vps() {
  local choice label
  while :; do
    if [ "${#SELECTED_VPS[@]}" -eq 1 ]; then
      label="${SELECTED_VPS[0]}"
    else
      label="${#SELECTED_VPS[@]} VPSs: ${SELECTED_VPS[*]}"
    fi
    _edit_selected_menu_print "$label"
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
