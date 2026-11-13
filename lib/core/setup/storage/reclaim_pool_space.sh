#!/bin/bash
# Give space freed inside the storage pool back to the real disk. Without this,
# deleting a VPS/snapshot frees space only inside VPSForge's disk image and the
# host's free space does not grow (measured: ~1.5GB stayed trapped).
reclaim_pool_space() {
  local pool_path zpool_name
  if [ "$(get_pool_driver default)" = "zfs" ] && command -v zpool >/dev/null 2>&1; then
    zpool_name=$(incus storage get default zfs.pool_name 2>/dev/null || true)
    zpool trim "${zpool_name:-default}" >/dev/null 2>&1 || true
    return 0
  fi
  pool_path=$(get_incus_pool_path 2>/dev/null) || return 0
  [ -d "$pool_path" ] || return 0
  command -v fstrim >/dev/null 2>&1 || return 0
  fstrim "$pool_path" >/dev/null 2>&1 || true
  repair_pool_quotas   # a delete can switch the disk limits off: switch them back on
}
