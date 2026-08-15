#!/bin/bash
# VPSForge v1.0.0 — Reinstall VPS menu.

reinstall_vps_menu() {
  local n x
  ask_vps_selection || return 1
  show_selection
  read -r -p "Type REINSTALL to erase and reinstall, or 0 to cancel: " x
  [ "$x" = "0" ] && { echo "Cancelled."; return 1; }
  [ "$x" = "REINSTALL" ] || { echo "Cancelled."; return 1; }

  for n in "${SELECTED_VPS[@]}"; do
    reinstall_single_vps_core "$n"
  done
  pause
  return 0
}
