#!/bin/bash
# Wizard step 4 of 5: the whole website, or only one folder of it (defaults to your last choice).
proxy_wizard_step_path() {
  local choice folder last
  last=$(pref_get proxy_path_choice 1)
  echo
  echo "Step 4 of 5 - Which part of the domain goes to this app?"
  echo "   1) The whole domain$([ "$last" = "1" ] && echo '   <- last used')"
  echo "   2) Only one folder, for example /api$([ "$last" = "2" ] && echo '   <- last used')"
  read -r -p "Choice [Enter=$last, 0=Back]: " choice </dev/tty
  choice="${choice:-$last}"
  [ "$choice" = "0" ] && return "$WIZARD_BACK"
  PW_PATH=""
  pref_set proxy_path_choice "$choice"
  if [ "$choice" = "2" ]; then
    local last_folder
    last_folder=$(pref_get proxy_folder "")
    read -r -p "Folder (example: /api)${last_folder:+ [Enter=$last_folder]} [0=Back]: " folder </dev/tty
    [ "$folder" = "0" ] && return "$WIZARD_BACK"
    folder="${folder:-$last_folder}"
    [ -n "$folder" ] || { echo "No folder given."; return 1; }
    PW_PATH="$folder"
    pref_set proxy_folder "$folder"
  fi
  return 0
}
