#!/bin/bash
# Stops a running VPS before rename and waits for it to shut down.
_rename_stop_if_running() {
  local old_name="$1"
  if is_vps_running "$old_name"; then
    echo "Stopping $old_name..."
    incus stop "$old_name" --force >/dev/null 2>&1 || true
    local wait_count=0
    while is_vps_running "$old_name" && [ $wait_count -lt 15 ]; do
      sleep 1
      wait_count=$((wait_count + 1))
    done
    return 1
  fi
  return 0
}
