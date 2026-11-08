#!/bin/bash
bulk_details_menu() {
  local n
  ask_vps_selection_enter_all || return
  for n in "${SELECTED_VPS[@]}"; do
    echo
    details "$n"
  done
}
