#!/bin/bash
# Reinstalls selected VPS instances with chosen OS images while preserving settings.
edit_os_for_selection() {
  local n first=1 image="" typed
  edit_ask_scope || return
  echo "This ERASES and reinstalls: ${SELECTED_VPS[*]}  (settings, IP, port and login are kept; files are lost)."
  read -r -p "Type REINSTALL to continue: " typed </dev/tty || typed=""
  [ "$typed" = "REINSTALL" ] || { echo "Cancelled."; return; }
  for n in "${SELECTED_VPS[@]}"; do
    if [ "$EDIT_SCOPE" = "2" ] && [ "$first" -eq 0 ]; then
      :  # same OS as the first VPS
    else
      ask_vps_image "$n" || { [ "$EDIT_SCOPE" = "2" ] && return; continue; }
      image="$SELECTED_IMAGE"
    fi
    first=0
    reinstall_single_vps_core "$n" "$image"
  done
}
