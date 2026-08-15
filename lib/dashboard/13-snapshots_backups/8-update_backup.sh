#!/bin/bash

update_vps_backup() {
  local name confirm
  ask_vps_selection "Select VPS container to update backup for: " || return
  [ "${#SELECTED_VPS[@]}" -eq 1 ] || { echo "Supports one VPS at a time."; return; }
  name="${SELECTED_VPS[0]}"

  if select_backup_file "Select backup file to OVERWRITE / UPDATE: "; then
    inspect_backup_file "$SELECTED_BACKUP_FILE"
    read -r -p "Overwrite and update '$(basename "$SELECTED_BACKUP_FILE")' with fresh data from $name? [y/N]: " confirm
    if [[ "${confirm,,}" =~ ^y ]]; then
      sync_vps_metadata "$name"
      local tmp_dir="${BACKUP_DIR}/.tmp"
      mkdir -p "$tmp_dir"
      local tmp_file_path="${tmp_dir}/$(basename "$SELECTED_BACKUP_FILE")"

      # Automatically disable and remove non-functional container swapfiles to prevent backup bloat
      incus exec "$name" -- sh -c "swapoff /swapfile 2>/dev/null || true"
      incus exec "$name" -- sh -c "rm -f /swapfile 2>/dev/null || true"

      echo "Exporting fresh backup for $name to temporary storage..."
      if incus export "$name" "$tmp_file_path"; then
        rm -f "$SELECTED_BACKUP_FILE"
        if mv "$tmp_file_path" "$SELECTED_BACKUP_FILE"; then
          echo "Backup updated successfully: $SELECTED_BACKUP_FILE"
          incus config show "$name" --expanded > "${SELECTED_BACKUP_FILE}.info" 2>/dev/null || true
        else
          echo "ERROR: Failed to move updated backup to final destination."
          return 1
        fi
      else
        echo "ERROR: Backup export failed. Original backup preserved."
        return 1
      fi
    else
      echo "Update cancelled."
    fi
  fi
}
