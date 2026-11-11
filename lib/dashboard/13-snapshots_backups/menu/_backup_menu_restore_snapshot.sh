#!/bin/bash
# Prompt for VPS and snapshot to restore.
_backup_menu_restore_snapshot() {
  local target_vps confirm
  ask_vps_selection "VPS name or number [0=Back, Enter=1]: " single || return
  [ "${#SELECTED_VPS[@]}" -eq 1 ] || { echo "Supports one VPS at a time."; pause; return; }
  target_vps="${SELECTED_VPS[0]}"
  if select_vps_snapshot "$target_vps" "Snapshot number or name to restore: "; then
    read -r -p "Restore '$target_vps' to '$SELECTED_SNAPSHOT'? Changes made after it are lost. [y/N]: " confirm </dev/tty || confirm=n
    [[ "${confirm,,}" =~ ^y ]] || { echo "Cancelled."; pause; return; }
    restore_vps_snapshot "$target_vps" "$SELECTED_SNAPSHOT"
    pause
  fi
}
