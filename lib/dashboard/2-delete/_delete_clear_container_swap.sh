#!/bin/bash
# Clears swapfile locks and removes immutable attributes inside and outside container storage pools.
_delete_clear_container_swap() {
  local n="$1" sf
  # a stopped VPS has nothing to switch off inside: the host-side loop below handles its file
  incus exec "$n" -- sh -c "swapoff -a 2>/dev/null || true" </dev/null >/dev/null 2>&1
  incus exec "$n" -- sh -c "chattr -i -a /swapfile 2>/dev/null || true" </dev/null >/dev/null 2>&1
  for sf in /var/lib/incus/storage-pools/*/containers/"$n"/rootfs/swapfile /var/lib/lxd/storage-pools/*/containers/"$n"/rootfs/swapfile; do
    if [ -f "$sf" ]; then
      swapoff "$sf" 2>/dev/null || true
      chattr -i -a "$sf" 2>/dev/null || true
      rm -f "$sf" 2>/dev/null || true
    fi
  done
}
