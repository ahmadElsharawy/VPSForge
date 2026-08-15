#!/bin/bash

restore_vps_snapshot() {
  local name="$1" snap_name="$2" was_running=false
  [ -z "$snap_name" ] && { echo "No snapshot specified."; return 1; }

  # Resolve numeric index if passed directly
  if [[ "$snap_name" =~ ^[0-9]+$ ]]; then
    local -a snaps=()
    mapfile -t snaps < <(incus snapshot list "$name" --format csv 2>/dev/null | cut -d',' -f1 || true)
    if [ "$snap_name" -ge 1 ] && [ "$snap_name" -le "${#snaps[@]}" ]; then
      snap_name="${snaps[$((snap_name-1))]}"
    fi
  fi

  if [ "$(get_state "$name")" = "RUNNING" ]; then
    was_running=true
    echo "Container $name is currently running. Stopping it to restore snapshot..."
    incus stop "$name" --force 2>/dev/null || true
  fi

  echo "Restoring $name to snapshot '$snap_name'..."
  if incus snapshot restore "$name" "$snap_name"; then
    echo "Snapshot '$snap_name' restored successfully."
    incus config set "$name" user.vpsforge.last_restore "$(date '+%Y-%m-%d %H:%M:%S UTC')" 2>/dev/null || true
    restore_vps_port_forwards_metadata "$name"
    if [ "$was_running" = true ]; then
      echo "Restarting container $name..."
      incus start "$name" 2>/dev/null || true
    fi
  else
    echo "Failed to restore snapshot '$snap_name'."
    if [ "$was_running" = true ]; then
      echo "Restarting container $name..."
      incus start "$name" 2>/dev/null || true
    fi
  fi
}
