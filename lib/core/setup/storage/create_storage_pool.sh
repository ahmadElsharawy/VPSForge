#!/bin/bash
# Create the Incus storage pool <name>. Prefers BTRFS (instant snapshots, quotas)
# and falls back to a plain directory pool on hosts whose kernel lacks btrfs, so
# VPSForge still works on any cloud VM.
create_storage_pool() {
  local name="${1:-default}"

  if incus storage create "$name" btrfs "size=$(default_pool_size_gib)GiB" >/dev/null 2>&1; then
    return 0
  fi

  echo "NOTICE: BTRFS is not available on this host; using a directory storage pool (no instant snapshots)." >&2
  incus storage create "$name" dir >/dev/null 2>&1
}
