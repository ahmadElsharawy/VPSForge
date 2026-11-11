#!/bin/bash
# Prompt to select and delete one or more backup archives and their metadata.
delete_backup_file() {
  local confirm target_file
  if select_backup_files "Select backup file(s) to DELETE (e.g. 1, 1,2, 1-3, A for All, 0=Back): "; then
    echo
    echo "Selected ${#SELECTED_BACKUP_FILES[@]} file(s) to delete:"
    for target_file in "${SELECTED_BACKUP_FILES[@]}"; do
      echo "  - $(basename "$target_file")"
    done
    read -r -p "Are you sure you want to delete these file(s)? [y/N]: " confirm </dev/tty
    if [[ "${confirm,,}" =~ ^y ]]; then
      for target_file in "${SELECTED_BACKUP_FILES[@]}"; do
        rm -f "$target_file" && echo "Backup file '$(basename "$target_file")' deleted."
        rm -f "${target_file}.info" 2>/dev/null || true
      done
    else
      echo "Deletion cancelled."
    fi
  fi
}
