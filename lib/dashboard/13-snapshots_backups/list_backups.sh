#!/bin/bash

BACKUP_FILES_RESULT=()

list_backup_files() {
  local filter_prefix="$1"
  local f size mtime idx=1
  mkdir -p "$BACKUP_DIR"
  BACKUP_FILES_RESULT=()

  while IFS= read -r f; do
    [ -f "$f" ] || continue
    if [ -n "$filter_prefix" ]; then
      local base
      base=$(basename "$f")
      if [[ "$base" != "${filter_prefix}-backup-"* && "$base" != "${filter_prefix}-"* ]]; then
        continue
      fi
    fi
    BACKUP_FILES_RESULT+=("$f")
  done < <(find "$BACKUP_DIR" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.tar" \) 2>/dev/null | sort -r || true)

  if [ "${#BACKUP_FILES_RESULT[@]}" -eq 0 ]; then
    if [ -n "$filter_prefix" ]; then
      echo "No backup files found for VPS '$filter_prefix' in $BACKUP_DIR."
    else
      echo "No backup files found in $BACKUP_DIR."
    fi
    return 1
  fi

  if [ -n "$filter_prefix" ]; then
    echo "Available Backup Files for VPS '$filter_prefix' in $BACKUP_DIR:"
  else
    echo "Available Backup Files in $BACKUP_DIR:"
  fi
  for i in "${!BACKUP_FILES_RESULT[@]}"; do
    f="${BACKUP_FILES_RESULT[$i]}"
    size=$(du -h "$f" 2>/dev/null | awk '{print $1}')
    mtime=$(stat -c "%y" "$f" 2>/dev/null | cut -d'.' -f1 || echo "-")
    printf "  %2d) %-40s (%s | %s)\n" "$((i+1))" "$(basename "$f")" "$size" "$mtime"
  done
  return 0
}
