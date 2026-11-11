#!/bin/bash
# Prompt for VPS and snapshot(s) to delete.
_backup_menu_delete_snapshot() {
  local target_vps confirm snap_name
  ask_vps_selection "VPS name or number [0=Back, Enter=1]: " single || return
  [ "${#SELECTED_VPS[@]}" -eq 1 ] || { echo "Supports one VPS at a time."; pause; return; }
  target_vps="${SELECTED_VPS[0]}"
  if select_vps_snapshots "$target_vps" "Snapshot number(s) to delete (e.g. 1, 1,2, 1-3, or A for All, 0=Cancel): "; then
    read -r -p "Delete ${#SELECTED_SNAPSHOTS[@]} snapshot(s) of '$target_vps' (${SELECTED_SNAPSHOTS[*]})? This cannot be undone. [y/N]: " confirm </dev/tty || confirm=n
    [[ "${confirm,,}" =~ ^y ]] || { echo "Cancelled."; pause; return; }
    for snap_name in "${SELECTED_SNAPSHOTS[@]}"; do
      delete_vps_snapshot "$target_vps" "$snap_name"
    done
    pause
  fi
}
