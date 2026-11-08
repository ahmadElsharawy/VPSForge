#!/bin/bash
# Rename the selected VPSs one by one, then keep the selection pointing at the new names.
edit_rename_selection() {
  local i name
  for i in "${!SELECTED_VPS[@]}"; do
    name="${SELECTED_VPS[$i]}"
    [ "${#SELECTED_VPS[@]}" -gt 1 ] && echo "--- $name ---"
    rename_vps_container "$name"
    [ -n "${RENAMED_VPS_NAME:-}" ] && SELECTED_VPS[$i]="$RENAMED_VPS_NAME"
  done
}
