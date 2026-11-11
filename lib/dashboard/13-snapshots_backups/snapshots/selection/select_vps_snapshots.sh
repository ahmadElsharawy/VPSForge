#!/bin/bash
# Prompts the user to select one, several, or all snapshots for a VPS container.
select_vps_snapshots() {
  local name="$1" prompt="${2:-Snapshot number, name, or A for All [0=Back, Enter=1]: }" choice idx snap
  SELECTED_SNAPSHOTS=()
  SELECTED_SNAPSHOT=""

  if ! list_vps_snapshots "$name"; then
    return 1
  fi

  read -r -p "$prompt" choice </dev/tty
  choice="${choice:-1}"
  [ "$choice" = "0" ] && return 1

  if parse_number_selection "$choice" "${#SNAPSHOT_NAMES_RESULT[@]}"; then
    for idx in "${SELECTED_NUMS[@]}"; do
      SELECTED_SNAPSHOTS+=("${SNAPSHOT_NAMES_RESULT[$((idx-1))]}")
    done
    [ "${#SELECTED_SNAPSHOTS[@]}" -gt 0 ] && SELECTED_SNAPSHOT="${SELECTED_SNAPSHOTS[0]}"
    return 0
  else
    for snap in "${SNAPSHOT_NAMES_RESULT[@]}"; do
      if [ "$snap" = "$choice" ]; then
        SELECTED_SNAPSHOTS+=("$choice")
        SELECTED_SNAPSHOT="$choice"
        return 0
      fi
    done
    echo "Invalid snapshot selection: $choice"
    return 1
  fi
}
