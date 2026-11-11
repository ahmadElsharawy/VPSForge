#!/bin/bash

# Creates a new snapshot for a VPS container after syncing metadata and removing swapfiles.
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
  # Refuse early if the name is taken, so cleanup can never delete a snapshot that was not made by this call.
  if incus snapshot list "$name" --format csv 2>/dev/null | cut -d',' -f1 | grep -qxF "$snap_name"; then
    echo "ERROR: A snapshot named '$snap_name' already exists for $name."
    return 1
  fi
  run_guarded "cleanup_partial_snapshot $(printf %q "$name") $(printf %q "$snap_name")" _snapshot_create "$name" "$snap_name"     && echo "Snapshot '$snap_name' created successfully."
}
