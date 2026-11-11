#!/bin/bash
# Print formatted list of backup files with index, size, and modification date.
_list_backup_files_print() {
  local i f size mtime
  for i in "${!BACKUP_FILES_RESULT[@]}"; do
    f="${BACKUP_FILES_RESULT[$i]}"
    size=$(du -h "$f" 2>/dev/null | awk '{print $1}')
    mtime=$(stat -c "%y" "$f" 2>/dev/null | cut -d'.' -f1 || echo "-")
    printf "  %2d) %-40s (%s | %s)\n" "$((i+1))" "$(basename "$f")" "$size" "$mtime"
  done
}
