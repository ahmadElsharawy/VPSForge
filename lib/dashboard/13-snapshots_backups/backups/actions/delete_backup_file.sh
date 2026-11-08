#!/bin/bash

delete_backup_file() {
  local confirm f
  if select_backup_files "Select backup file(s) to DELETE (e.g. 1, 1,2, 1-3, A for All, 0=Back): "; then
    echo
    echo "Selected ${#SELECTED_BACKUP_FILES[@]} file(s) to delete:"
    for f in "${SELECTED_BACKUP_FILES[@]}"; do
      echo "  - $(basename "$f")"
    done
    read -r -p "Are you sure you want to delete these file(s)? [y/N]: " confirm </dev/tty
    if [[ "${confirm,,}" =~ ^y ]]; then
      for f in "${SELECTED_BACKUP_FILES[@]}"; do
        rm -f "$f" && echo "Backup file '$(basename "$f")' deleted."
        rm -f "${f}.info" 2>/dev/null || true
      done
    else
      echo "Deletion cancelled."
    fi
  fi
}
