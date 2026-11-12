#!/bin/bash
# Give space freed inside the storage pool back to the real disk. Without this,
# deleting a VPS/snapshot frees space only inside VPSForge's disk image and the
# host's free space does not grow (measured: ~1.5GB stayed trapped).
reclaim_pool_space() {
  local pool_path
  pool_path=$(get_incus_pool_path 2>/dev/null) || return 0
  [ -d "$pool_path" ] || return 0
  command -v fstrim >/dev/null 2>&1 || return 0
  fstrim "$pool_path" >/dev/null 2>&1 || true
  repair_pool_quotas   # a delete can switch the disk limits off: switch them back on
}
