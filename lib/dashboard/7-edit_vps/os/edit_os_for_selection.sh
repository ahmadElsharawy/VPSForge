#!/bin/bash
# Reinstall / change the OS of the selected VPSs (settings, IP, port and login are kept).
# One VPS: pick the OS. Several: each separately, or the same OS for all.
edit_os_for_selection() {
  local n first=1 image=""
  edit_ask_scope || return
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
