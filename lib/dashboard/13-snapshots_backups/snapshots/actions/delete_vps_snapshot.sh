#!/bin/bash

# Deletes a snapshot from a VPS container and reclaims pool space.
delete_vps_snapshot() {
  local name="${1:-}" snap_name="${2:-}"
  [ -z "$snap_name" ] && { echo "No snapshot specified."; return 1; }

  snap_name="$(_resolve_snapshot_name "$name" "$snap_name")"

  echo "Deleting snapshot '$snap_name' from $name..."
  incus snapshot delete "$name" "$snap_name" && echo "Snapshot '$snap_name' deleted." && reclaim_pool_space
}
