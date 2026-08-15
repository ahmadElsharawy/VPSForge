#!/bin/bash

shell_menu() {
  ask_vps_selection "Select VPS by number, name, or A for All [0=Back, Enter=1]: " || return
  [ "${#SELECTED_VPS[@]}" -eq 1 ] || { echo "Shell supports one VPS at a time."; return; }
  incus exec "${SELECTED_VPS[0]}" -- bash
}
