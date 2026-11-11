#!/bin/bash
# Prompt for VPS selection and export full backups.
_backup_menu_export() {
  local target_vps
  ask_vps_selection "VPS name or number [0=Back, Enter=1]: " || return
  for target_vps in "${SELECTED_VPS[@]}"; do
    export_vps_backup "$target_vps"
  done
  pause
}
