#!/bin/bash

SELECTED_BACKUP_FILES=()
SELECTED_BACKUP_FILE=""

select_backup_files() {
  local prompt="${1:-Select backup file [0=Back, Enter=1]: }" filter_prefix="${2:-}" c custom_path idx
  SELECTED_BACKUP_FILES=()
  SELECTED_BACKUP_FILE=""

  # Ask user if they want to filter by VPS container when prefix is not explicitly passed
  if [ -z "$filter_prefix" ]; then
    clear
    echo "================================================"
    echo "              SELECT BACKUP FILE"
    echo "================================================"
    echo "1) Filter backups by an existing VPS container"
    echo "2) List all backup files (List All / Custom)"
    echo "0) Back"
    echo
    local choice
    read -r -p "Choice [0=Back, Enter=1]: " choice </dev/tty
    choice="${choice:-1}"
    case "$choice" in
      1)
        if ! ask_vps_selection "Select VPS to filter backups: "; then
          return 1
        fi
        [ "${#SELECTED_VPS[@]}" -eq 1 ] || { echo "Please select one VPS."; pause; return 1; }
        filter_prefix="${SELECTED_VPS[0]}"
        clear
        ;;
      2)
        filter_prefix=""
        clear
        ;;
      0)
        return 1
        ;;
      *)
        echo "Invalid choice."
        sleep 1
        return 1
        ;;
    esac
  fi

  if list_backup_files "$filter_prefix"; then
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

select_backup_file() {
  select_backup_files "$@"
}
