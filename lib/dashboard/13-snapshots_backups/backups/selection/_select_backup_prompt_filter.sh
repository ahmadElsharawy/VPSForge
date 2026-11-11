#!/bin/bash
# Prompt user to choose between filtering backups by VPS or listing all.
_select_backup_prompt_filter() {
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
}
