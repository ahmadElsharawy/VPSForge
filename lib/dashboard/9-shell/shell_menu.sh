#!/bin/bash

# Opens an interactive bash shell inside a selected VPS container.
shell_menu() {
  ask_vps_selection "Select VPS by number or name [0=Back, Enter=1]: " single || return
  [ "${#SELECTED_VPS[@]}" -eq 1 ] || { echo "Shell supports one VPS at a time."; return; }
  local target="${SELECTED_VPS[0]}"
  is_vps_running "$target" || { echo "$target is not running. Start it first (main menu 3)."; return; }
  set_guest_hostname "$target"
  incus exec "$target" -- bash
}
