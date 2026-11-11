#!/bin/bash
# Validate that a backup archive file exists, is readable, and not damaged.
_import_validate_backup_file() {
  local file_path="$1"
  [ -f "$file_path" ] || { echo "File not found: $file_path"; return 1; }

  # A damaged backup is useless and would only waste disk: say so and delete it (nothing else is touched).
  if command -v zstd >/dev/null 2>&1 && ! tar -tf "$file_path" >/dev/null 2>&1; then
    if [[ "$file_path" == "${BACKUP_DIR:-/opt/vpsforge-backups}"/* ]]; then
      echo "ERROR: the backup file is damaged or unreadable. It was deleted: $(basename "$file_path")"
      rm -f "$file_path" "${file_path}.info"
    else
      echo "ERROR: the file looks damaged or unreadable. It is outside the backup folder, so it was NOT deleted: $file_path"
    fi
    return 1
  fi
  return 0
}
