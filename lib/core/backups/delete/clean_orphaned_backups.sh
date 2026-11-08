#!/bin/bash
# Find backup files whose VPS no longer exists, show their size, and delete
# them after confirmation. Also removes stray .info files with no backup.
clean_orphaned_backups() {
  local file owner total_kb=0 kb
  local -a orphans=()

  [ -d "$BACKUP_DIR" ] || { echo "No backup folder yet."; return 0; }

  while read -r file; do
    [ -n "$file" ] || continue
    owner=$(extract_container_name_from_backup_filename "$file")
    if ! incus info "$owner" >/dev/null 2>&1; then
      orphans+=("$file")
      kb=$(du -sk "$file" | cut -f1)
      total_kb=$((total_kb + kb))
      printf '  ORPHAN  %-45s %s\n' "$(basename "$file")" "$(du -h "$file" | cut -f1)"
    fi
  done < <(find "$BACKUP_DIR" -maxdepth 1 -type f \( -name '*.tar' -o -name '*.tar.gz' \) | sort)

  # .info files whose backup is gone
  while read -r file; do
    [ -f "${file%.info}" ] || rm -f "$file"
  done < <(find "$BACKUP_DIR" -maxdepth 1 -type f -name '*.info')

  if [ "${#orphans[@]}" -eq 0 ]; then
    echo "No orphaned backups. Nothing to clean."
    return 0
  fi

  echo "Total space used by orphaned backups: $((total_kb / 1024))MB"
  local answer
  read -r -p "Delete these ${#orphans[@]} orphaned backup(s)? [y/N]: " answer
  if [[ "${answer,,}" =~ ^y ]]; then
    for file in "${orphans[@]}"; do rm -f "$file" "${file}.info"; done
    echo "Deleted. Freed about $((total_kb / 1024))MB."
  else
    echo "Kept."
  fi
}
