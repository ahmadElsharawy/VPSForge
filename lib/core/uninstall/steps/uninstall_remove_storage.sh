#!/bin/bash
# Delete the storage pool (and its disk image file), the bridge, and cached images.
uninstall_remove_storage() {
  local fp
  echo "[3/7] Removing storage pool, bridge and cached images..."
  if [ "${UNINSTALL_FOREIGN_INSTANCES:-0}" -gt 0 ]; then
    echo "  (other containers still use the pool and bridge: kept)"
    return 0
  fi

  while read -r fp; do
    [ -n "$fp" ] && uninstall_run incus image delete "$fp"
  done < <(incus image list -c f --format csv 2>/dev/null)

  uninstall_run incus profile device remove default root
  uninstall_run incus profile device remove default eth0
  uninstall_run incus storage delete default
  uninstall_run incus network delete incusbr0
  [ "${UNINSTALL_DRY_RUN:-0}" = "1" ] || rm -f /var/lib/incus/disks/default.img
}
