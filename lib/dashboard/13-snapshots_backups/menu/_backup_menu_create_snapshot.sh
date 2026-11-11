#!/bin/bash
# Prompt for VPS and snapshot name then create snapshot.
_backup_menu_create_snapshot() {
  local target_vps snap_name
  ask_vps_selection "VPS name or number [0=Back, Enter=1]: " single || return
  [ "${#SELECTED_VPS[@]}" -eq 1 ] || { echo "Snapshot supports one VPS at a time."; pause; return; }
  target_vps="${SELECTED_VPS[0]}"
  show_example "before-update  (a name to find this snapshot later)"
  read -r -p "Snapshot name [Enter = auto-timestamp]: " snap_name
  create_vps_snapshot "$target_vps" "$snap_name"
  pause
}
