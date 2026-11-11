#!/bin/bash
# Clears swapfile locks and removes immutable attributes inside and outside container storage pools.
_delete_clear_container_swap() {
  local n="$1" sf
  incus exec "$n" -- sh -c "swapoff -a 2>/dev/null || true"
  incus exec "$n" -- sh -c "chattr -i -a /swapfile 2>/dev/null || true"
  for sf in /var/lib/incus/storage-pools/*/containers/"$n"/rootfs/swapfile /var/lib/lxd/storage-pools/*/containers/"$n"/rootfs/swapfile; do
    if [ -f "$sf" ]; then
      swapoff "$sf" 2>/dev/null || true
      chattr -i -a "$sf" 2>/dev/null || true
      rm -f "$sf" 2>/dev/null || true
    fi
  done
}
