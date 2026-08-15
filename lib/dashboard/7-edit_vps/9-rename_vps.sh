#!/bin/bash

rename_vps_container() {
  local old_name="$1" new_name="$2"
  [ -n "$old_name" ] || return 1
  if [ -z "$new_name" ]; then
    read -r -p "Enter new VPS name [current: $old_name]: " new_name </dev/tty
  fi
  [ -n "$new_name" ] || { echo "Rename cancelled."; return 0; }
  [ "$old_name" != "$new_name" ] || { echo "New name is the same as current name."; return 0; }

  if incus list -c n --format csv 2>/dev/null | grep -Fxq "$new_name"; then
    echo "ERROR: A VPS with name '$new_name' already exists."
    return 1
  fi

  echo "Renaming VPS from '$old_name' to '$new_name'..."
  local was_running=0
  if [ "$(get_state "$old_name")" = "RUNNING" ]; then
    was_running=1
    echo "Stopping $old_name..."
    incus stop "$old_name" --force >/dev/null 2>&1 || true
  fi

  if incus rename "$old_name" "$new_name"; then
    if [ -f "/etc/caddy/vpsforge/${old_name}.caddy" ]; then
      mv "/etc/caddy/vpsforge/${old_name}.caddy" "/etc/caddy/vpsforge/${new_name}.caddy"
      systemctl reload-or-restart caddy >/dev/null 2>&1 || true
    fi
    sync_vps_metadata "$new_name"
    echo "SUCCESS: VPS renamed to '$new_name'."

    if [ $was_running -eq 1 ]; then
      echo "Starting $new_name..."
      incus start "$new_name" >/dev/null 2>&1 || true
    fi
  else
    echo "ERROR: Failed to rename VPS container."
    return 1
  fi
}
