#!/bin/bash
# Delete backup files that cannot be read back (damaged or cut short), with their .info files.
# Healthy backups are never touched, and a file younger than an hour may still be copied in, so it is left alone. Skipped when zstd is missing (good files would look damaged).
delete_damaged_backups() {
  local file
  [ -d "$BACKUP_DIR" ] || return 0
  command -v zstd >/dev/null 2>&1 || return 0
  pgrep -x incus -a 2>/dev/null | grep -q -e ' export ' -e ' import ' && return 0
  while read -r file; do
    [ -n "$file" ] || continue
    if ! tar -tf "$file" >/dev/null 2>&1; then
      echo "  DAMAGED backup deleted: $(basename "$file")"
      rm -f "$file" "${file}.info"
    fi
  done < <(find "$BACKUP_DIR" -maxdepth 1 -type f -mmin +60 \( -name '*.tar' -o -name '*.tar.gz' \) | sort)
}
