#!/bin/bash
# Remove stray .info metadata files in the backup directory whose archive is missing.
_clean_stray_backup_info_files() {
  local file
  [ -d "$BACKUP_DIR" ] || return 0
  while read -r file; do
    [ -f "${file%.info}" ] || rm -f "$file"
  done < <(find "$BACKUP_DIR" -maxdepth 1 -type f -name '*.info')
}
