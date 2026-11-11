#!/bin/bash
# Prompt user to select backup file(s) from listed results, custom path, or cancel.
_select_backup_from_list() {
  local prompt="$1" c custom_path idx
  echo "   0) Back / Cancel"
  echo "   A) All Backup Files"
  echo "   C) Enter custom file path"
  read -r -p "$prompt" c </dev/tty
  c="${c:-1}"
  if [ "$c" = "0" ]; then
    return 1
  elif [[ "${c,,}" = "c" ]]; then
    read -r -p "Path to custom backup file (.tar/.tar.gz): " custom_path </dev/tty
    if [ -f "$custom_path" ]; then
      SELECTED_BACKUP_FILES+=("$custom_path")
      SELECTED_BACKUP_FILE="$custom_path"
      return 0
    else
      echo "File not found: $custom_path"
      pause
      return 1
    fi
  elif parse_number_selection "$c" "${#BACKUP_FILES_RESULT[@]}"; then
    for idx in "${SELECTED_NUMS[@]}"; do
      SELECTED_BACKUP_FILES+=("${BACKUP_FILES_RESULT[$((idx-1))]}")
    done
    [ "${#SELECTED_BACKUP_FILES[@]}" -gt 0 ] && SELECTED_BACKUP_FILE="${SELECTED_BACKUP_FILES[0]}"
    return 0
  else
    echo "Invalid selection."
    pause
    return 1
  fi
}
