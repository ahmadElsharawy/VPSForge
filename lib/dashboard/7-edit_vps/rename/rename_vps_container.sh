#!/bin/bash
# Renames a VPS container, updating network routes, metadata, and guest hostname.

rename_vps_container() {
  local old_name="${1:-}" new_name="${2:-}"
  RENAMED_VPS_NAME=""
  [ -n "$old_name" ] || return 1
  if [ -z "$new_name" ]; then
    show_example "web1  (letters, digits, - _ . and no spaces)"
    read -r -p "Enter new VPS name [current: $old_name, 0=Back]: " new_name </dev/tty
  fi
  { [ "$new_name" = "0" ] || [ -z "$new_name" ]; } && { echo "Rename cancelled."; return 0; }
  [ "$old_name" != "$new_name" ] || { echo "New name is the same as current name."; return 0; }

  _rename_validate_new_name "$new_name" || return 1

  echo "Renaming VPS from '$old_name' to '$new_name'..."
  local was_running=0
  _rename_stop_if_running "$old_name" || was_running=1

  if incus rename "$old_name" "$new_name"; then
    RENAMED_VPS_NAME="$new_name"
    _rename_vps_post_config "$old_name" "$new_name" "$was_running"
    echo "SUCCESS: VPS renamed to '$new_name'."
    return 0
  else
    echo "ERROR: Failed to rename VPS container."
    [ "$was_running" -eq 1 ] && incus start "$old_name" >/dev/null 2>&1 || true
    return 1
  fi
}
