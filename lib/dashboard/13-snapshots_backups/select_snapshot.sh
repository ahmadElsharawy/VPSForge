#!/bin/bash

SELECTED_SNAPSHOTS=()
SELECTED_SNAPSHOT=""

select_vps_snapshots() {
  local name="$1" prompt="${2:-Snapshot number, name, or A for All [0=Back, Enter=1]: }" c idx snap
  SELECTED_SNAPSHOTS=()
  SELECTED_SNAPSHOT=""

  if ! list_vps_snapshots "$name"; then
    return 1
  fi

  read -r -p "$prompt" c </dev/tty
  c="${c:-1}"
  [ "$c" = "0" ] && return 1

  if parse_number_selection "$c" "${#SNAPSHOT_NAMES_RESULT[@]}"; then
    for idx in "${SELECTED_NUMS[@]}"; do
      SELECTED_SNAPSHOTS+=("${SNAPSHOT_NAMES_RESULT[$((idx-1))]}")
    done
    [ "${#SELECTED_SNAPSHOTS[@]}" -gt 0 ] && SELECTED_SNAPSHOT="${SELECTED_SNAPSHOTS[0]}"
    return 0
  else
    for snap in "${SNAPSHOT_NAMES_RESULT[@]}"; do
      if [ "$snap" = "$c" ]; then
        SELECTED_SNAPSHOTS+=("$c")
        SELECTED_SNAPSHOT="$c"
        return 0
      fi
    done
    echo "Invalid snapshot selection: $c"
    return 1
  fi
}

select_vps_snapshot() {
  select_vps_snapshots "$@"
}
