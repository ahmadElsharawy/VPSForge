#!/bin/bash
# Create the Incus storage pool <name>. Prefers ZFS (inside a VPS, df shows only that VPS's own
# disk limit), then BTRFS (instant snapshots, quotas), and falls back to a plain directory pool
# on hosts whose kernel lacks both, so VPSForge still works on any cloud VM.
create_storage_pool() {
  local name="${1:-default}"

  if command -v zpool >/dev/null 2>&1 && modprobe zfs >/dev/null 2>&1 \
     && incus storage create "$name" zfs "size=$(default_pool_size_gib)GiB" >/dev/null 2>&1; then
    tune_zfs_pool "$name"
    return 0
  fi

  if incus storage create "$name" btrfs "size=$(default_pool_size_gib)GiB" >/dev/null 2>&1; then
    return 0
  fi

  echo "NOTICE: ZFS and BTRFS are not available on this host; using a directory storage pool (no instant snapshots)." >&2
  incus storage create "$name" dir >/dev/null 2>&1
}
