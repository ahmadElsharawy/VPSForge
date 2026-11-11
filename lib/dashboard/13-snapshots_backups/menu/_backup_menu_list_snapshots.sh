#!/bin/bash
# Prompt for VPS and list its snapshots.
_backup_menu_list_snapshots() {
  ask_vps_selection "VPS name or number [0=Back, Enter=1]: " single || return
  [ "${#SELECTED_VPS[@]}" -eq 1 ] || { echo "Supports one VPS at a time."; pause; return; }
  list_vps_snapshots "${SELECTED_VPS[0]}"
  pause
}
