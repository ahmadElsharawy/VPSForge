#!/bin/bash
# Refresh an existing backup archive with current container data.
update_vps_backup() {
  local name confirm
  ask_vps_selection "Select VPS container to update backup for: " single || return
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
      backup_space_check "$name" || return 1
      if run_guarded "cleanup_partial_backup $(printf %q "$name") $(printf %q "$tmp_file_path")" _export_instance "$name" "$tmp_file_path"; then
        if mv -f "$tmp_file_path" "$SELECTED_BACKUP_FILE"; then   # replaces the old file in one step: it is never deleted before the new one is in place
          echo "Backup updated successfully: $SELECTED_BACKUP_FILE"
          incus config show "$name" --expanded > "${SELECTED_BACKUP_FILE}.info" 2>/dev/null || true
        else
          echo "ERROR: Failed to move updated backup to final destination."
          return 1
        fi
      else
        echo "The original backup was kept untouched."
        return 1
      fi
    else
      echo "Update cancelled."
    fi
  fi
}
