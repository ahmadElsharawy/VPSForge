#!/bin/bash
# Prints the resource and configuration editing menu options for selected VPSs.
_edit_selected_menu_print() {
  local label="$1"
  echo
  echo "Editing: $label"
  echo "0) Back"
  echo "1) Change RAM                  e.g. 512 MB for a small site"
  echo "2) Change CPU                  e.g. 1 core"
  echo "3) Change Disk                 e.g. 10 GB"
  echo "4) Change Network Speed        e.g. 100 Mbit"
  echo "5) Change Traffic Data Limit (Download/Upload Quota)   e.g. 100 GB per month"
  echo "6) Change SSH Port             e.g. 2222"
  echo "7) Change Username             e.g. admin"
  echo "8) Change Password"
  echo "9) Rename VPS Container      e.g. web1"
  echo "10) Change Internal IP       e.g. 10.x.x.150"
  echo "11) Swap IP & Port with another VPS   (exchange addresses of two VPSs)"
  echo "12) Reinstall / Change OS Image   e.g. switch to Alpine (tiny) or Debian"
}
