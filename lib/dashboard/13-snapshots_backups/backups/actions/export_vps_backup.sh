#!/bin/bash
# Export a full container backup archive with preview and space checks.
export_vps_backup() {
  local name="$1" file_path default_name custom_name
  sync_vps_metadata "$name"
  _export_vps_backup_preview "$name" || return 0

  mkdir -p "$BACKUP_DIR"
  default_name="${name}-backup-$(date +%Y%m%d-%H%M%S).tar"
  show_example "web1-before-upgrade   (saved in $BACKUP_DIR)"
  read -r -p "Enter backup filename [default: $default_name]: " custom_name </dev/tty
  custom_name=$(echo "$custom_name" | tr ' ' '_' | sed 's/[^A-Za-z0-9_.-]//g')
  if [ -n "$custom_name" ]; then
    if [[ "$custom_name" != *.tar && "$custom_name" != *.tar.gz ]]; then
      custom_name="${custom_name}.tar"
    fi
    file_path="${BACKUP_DIR}/${custom_name}"
  else
    file_path="${BACKUP_DIR}/${default_name}"
  fi
  if [ -e "$file_path" ]; then
    echo "ERROR: a backup named '$(basename "$file_path")' already exists. Choose another name (nothing was changed)."
    return 1
  fi
  local tmp_dir="${BACKUP_DIR}/.tmp"
  mkdir -p "$tmp_dir"
  local tmp_file_path="${tmp_dir}/$(basename "$file_path")"

  # Automatically disable and remove non-functional container swapfiles to prevent backup bloat
  incus exec "$name" -- sh -c "swapoff /swapfile 2>/dev/null || true"
  incus exec "$name" -- sh -c "rm -f /swapfile 2>/dev/null || true"

  echo "Exporting backup for $name to temporary storage..."
  backup_space_check "$name" || return 1
  # Guarded: if the export fails or is stopped, the half-written file is deleted and the space returned.
  if run_guarded "cleanup_partial_backup $(printf %q "$name") $(printf %q "$tmp_file_path")" _export_instance "$name" "$tmp_file_path"; then
    if mv "$tmp_file_path" "$file_path"; then
      echo "Backup saved: $file_path"
      incus config show "$name" --expanded > "${file_path}.info" 2>/dev/null || true
    else
      echo "ERROR: Failed to move backup to final destination."
      return 1
    fi
  else
    return 1
  fi
}
