#!/bin/bash

create_vps_snapshot() {
  local name="${1:-}" snap_name="${2:-}"
  [ -z "$snap_name" ] && snap_name="snap-$(date +%Y%m%d-%H%M%S)"
  snap_name=$(echo "$snap_name" | tr ' ' '_' | sed 's/[^a-zA-Z0-9_.-]//g')
  [ -z "$snap_name" ] && snap_name="snap-$(date +%Y%m%d-%H%M%S)"
  
  # Automatically disable and remove non-functional container swapfiles to prevent snapshot bloat
  incus exec "$name" -- sh -c "swapoff /swapfile 2>/dev/null || true"
  incus exec "$name" -- sh -c "rm -f /swapfile 2>/dev/null || true"

  sync_vps_metadata "$name"
  echo "Creating snapshot '$snap_name' for $name..."
  incus snapshot create "$name" "$snap_name" && echo "Snapshot '$snap_name' created successfully."
}
