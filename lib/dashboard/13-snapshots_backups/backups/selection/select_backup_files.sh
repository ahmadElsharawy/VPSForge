#!/bin/bash
# Select one or more backup files with optional container filtering or custom path.
select_backup_files() {
  local prompt="${1:-Select backup file [0=Back, Enter=1]: }" filter_prefix="${2:-}" custom_path
  SELECTED_BACKUP_FILES=()
  SELECTED_BACKUP_FILE=""

  # Ask user if they want to filter by VPS container when prefix is not explicitly passed
  if [ -z "$filter_prefix" ]; then
    _select_backup_prompt_filter || return 1
  fi

  if list_backup_files "$filter_prefix"; then
    _select_backup_from_list "$prompt"
  else
    read -r -p "Path to custom backup file (.tar/.tar.gz, or 0=Back): " custom_path </dev/tty
    [ "$custom_path" = "0" ] && return 1
    if [ -f "$custom_path" ]; then
      SELECTED_BACKUP_FILES+=("$custom_path")
      SELECTED_BACKUP_FILE="$custom_path"
      return 0
    else
      [ -n "$custom_path" ] && echo "File not found: $custom_path"
      pause
      return 1
    fi
  fi
}
