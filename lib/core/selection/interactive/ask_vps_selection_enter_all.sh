#!/bin/bash
# For Details and Connection menus: pressing Enter selects all.
ask_vps_selection_enter_all() {
  local input
  list_available_vps || return 1
  read -r -p "Select VPS by number, name, or A for All [0=Back, Enter=All]: " input </dev/tty
  input="${input:-All}"
  if [ "$input" = "0" ]; then
    echo "Cancelled."
    return 1
  fi
  normalize_selection "$input" || return 1
  [ "${#SELECTED_VPS[@]}" -gt 0 ] || { echo "No VPS containers selected."; return 1; }
}
