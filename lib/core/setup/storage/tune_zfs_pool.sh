#!/bin/bash
# Tune a new ZFS pool for small servers: lz4 compression, automatic trim, and a capped ARC cache
# (limit set now and saved in /etc/modprobe.d/vpsforge-zfs.conf; uninstall removes that file).
# Every step is best effort: a failure here never stops the setup.
#   tune_zfs_pool <incus pool name>
tune_zfs_pool() {
  local name="${1:-default}" zpool_name mem_kb arc
  zpool_name=$(incus storage get "$name" zfs.pool_name 2>/dev/null || true)
  [ -n "$zpool_name" ] || zpool_name="$name"

  zfs set compression=lz4 "$zpool_name" >/dev/null 2>&1 || true
  zpool set autotrim=on "$zpool_name" >/dev/null 2>&1 || true
  # A VPS's disk limit counts only its own live files (like df shows), not the owner's snapshots.
  incus storage set "$name" volume.zfs.use_refquota true >/dev/null 2>&1 || true

  mem_kb=$(awk '/^MemTotal:/{print $2; exit}' /proc/meminfo 2>/dev/null)
  arc=$(zfs_arc_max_bytes "$mem_kb") || return 0
  echo "$arc" > /sys/module/zfs/parameters/zfs_arc_max 2>/dev/null || true
  mkdir -p /etc/modprobe.d 2>/dev/null || true
  echo "options zfs zfs_arc_max=$arc" > /etc/modprobe.d/vpsforge-zfs.conf 2>/dev/null || true
  return 0
}
