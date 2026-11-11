#!/bin/bash

# Restores a VPS container to a specified snapshot.
restore_vps_snapshot() {
  local name="${1:-}" snap_name="${2:-}" was_running=false
  [ -z "$snap_name" ] && { echo "No snapshot specified."; return 1; }

  snap_name="$(_resolve_snapshot_name "$name" "$snap_name")"

  if is_vps_running "$name"; then
    was_running=true
    echo "Container $name is currently running. Stopping it to restore snapshot..."
    incus stop "$name" --force 2>/dev/null || true
    local wait_count=0
    while is_vps_running "$name" && [ $wait_count -lt 15 ]; do
      sleep 1
      wait_count=$((wait_count + 1))
    done
  fi

  local kept_tunnels
  kept_tunnels=$(incus config get "$name" user.vpsforge.tunnels 2>/dev/null || true)
  echo "Restoring $name to snapshot '$snap_name'..."
  if incus snapshot restore "$name" "$snap_name"; then
    echo "Snapshot '$snap_name' restored successfully."
    _restore_snapshot_post_config "$name" "$kept_tunnels"
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
    return 1
  fi
}
