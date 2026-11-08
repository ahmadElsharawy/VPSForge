#!/bin/bash
# Menu 16: clone a VPS (an instant copy to experiment on).
clone_vps_menu() {
  local src default_name new answer
  echo "----------------------------------------------------------------"
  echo "CLONE A VPS: makes an exact copy to experiment on (instant, almost no extra disk)."
  select_vps || return
  src="$SELECTED"
  default_name="${src}-clone"
  incus info "$default_name" >/dev/null 2>&1 && default_name="${src}-clone-$(date +%H%M)"

  read -r -p "Name for the copy [Enter=$default_name, 0=Back]: " new
  [ "$new" = "0" ] && return
  new="${new:-$default_name}"

  read -r -p "Make '$new' as an exact copy of '$src'? [Y/n]: " answer
  [[ "${answer,,}" =~ ^n ]] && { echo "Cancelled."; return; }

  clone_vps "$src" "$new"
  pause
}
