#!/bin/bash
# Single-VPS selection (shell access, websites, clone ...). Enter picks the VPS you used last time.
select_vps() {
  local default last
  list_available_vps || return 1
  last=$(pref_get last_vps "")
  default=1
  [ -n "$last" ] && incus info "$last" >/dev/null 2>&1 && default="$last"

  read -r -p "Select VPS by number or name [0=Back, Enter=$default]: " SELECTED </dev/tty
  SELECTED="${SELECTED:-$default}"
  if [ "$SELECTED" = "0" ]; then
    echo "Cancelled."
    return 1
  fi
  if [[ "$SELECTED" =~ ^[0-9]+$ ]] && [ "$SELECTED" -ge 1 ] && [ "$SELECTED" -le "${#AVAILABLE_VPS_LIST[@]}" ]; then
    local idx=$((SELECTED - 1))
    SELECTED="${AVAILABLE_VPS_LIST[$idx]}"
  elif [[ "$SELECTED" =~ ^[0-9]+$ ]]; then
    SELECTED="${VPS_PREFIX}${SELECTED}"
  fi
  incus info "$SELECTED" >/dev/null 2>&1 || { echo "Not found: $SELECTED"; return 1; }
  pref_set last_vps "$SELECTED"
}
