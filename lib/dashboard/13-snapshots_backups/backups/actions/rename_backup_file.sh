#!/bin/bash

rename_backup_file() {
  if select_backup_file "Select backup file to RENAME: "; then
    local old_file="$SELECTED_BACKUP_FILE"
    local old_name
    old_name=$(basename "$old_file")
    
    echo "Current backup file: $old_name"
    read -r -p "Enter new backup filename [e.g. custom-backup.tar]: " new_name </dev/tty
    [ -n "$new_name" ] || { echo "Rename cancelled."; return 0; }

    if [[ "$new_name" != *.tar && "$new_name" != *.tar.gz ]]; then
      new_name="${new_name}.tar"
    fi
    local new_file="${BACKUP_DIR}/${new_name}"

    if [ -f "$new_file" ]; then
      echo "ERROR: A backup file with name '$new_name' already exists."
      return 1
    fi

    echo "Renaming '$old_name' to '$new_name'..."
    mv "$old_file" "$new_file"
    if [ -f "${old_file}.info" ]; then
      mv "${old_file}.info" "${new_file}.info"
      echo "Renamed accompanying .info metadata file to '${new_name}.info'."
    fi
    echo "SUCCESS: Backup file renamed to $new_name"
  fi
}
