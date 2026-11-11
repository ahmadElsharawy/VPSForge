#!/bin/bash

# Displays the menu to confirm and delete selected VPS containers.
delete_vps_menu() {
  local n x
  ask_vps_selection || return 1
  show_selection
  read -r -p "Type DELETE to permanently delete, or 0 to cancel: " x
  [ "$x" = "0" ] && { echo "Cancelled."; return 1; }
  [ "$x" = "DELETE" ] || { echo "Cancelled."; return 1; }

  for n in "${SELECTED_VPS[@]}"; do
    _delete_single_vps "$n"
  done
  echo "Giving freed disk space back to the server..."
  reclaim_pool_space
  systemctl reload-or-restart caddy >/dev/null 2>&1 || true
  save_iptables
  pause
  return 0
}
