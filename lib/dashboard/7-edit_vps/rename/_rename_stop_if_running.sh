#!/bin/bash
# Stops a running VPS before rename and waits for it to shut down.
_rename_stop_if_running() {
  local old_name="$1"
  if is_vps_running "$old_name"; then
    echo "Stopping $old_name..."
    # wait for the real stop; if the stop command itself failed there is nothing to wait for
    if incus stop "$old_name" --force >/dev/null 2>&1; then
      while is_vps_running "$old_name"; do
        sleep 1
      done
    fi
    return 1
  fi
  return 0
}
