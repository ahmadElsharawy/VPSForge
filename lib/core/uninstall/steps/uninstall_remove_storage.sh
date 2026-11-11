#!/bin/bash
# Delete the storage pool (and its disk image file), the bridge, and cached images.
uninstall_remove_storage() {
  local fp
  echo "[3/7] Removing storage pool, bridge and cached images..."
  if [ "${UNINSTALL_FOREIGN_INSTANCES:-0}" -gt 0 ]; then
    echo "  (other containers still use the pool and bridge: kept)"
    UNINSTALL_KEPT_INCUS=1
    return 0
  fi

  # Incus was on this server before VPSForge: its pool, bridge and images are the owner's.
  # (Older records have no flags: then the package list tells whether Incus was already installed.)
  if [ -f "$PRE_INSTALL_DIR/had_incus_pool" ] || [ -f "$PRE_INSTALL_DIR/had_incus_bridge" ] || \
     grep -qxE 'incus|incus-base' "$PRE_INSTALL_DIR/packages_all.txt" 2>/dev/null; then
    echo "  (Incus was here before VPSForge: its storage pool, bridge and images are kept)"
    UNINSTALL_KEPT_INCUS=1
    return 0
  fi
  while read -r fp; do
    [ -n "$fp" ] && uninstall_run incus image delete "$fp"
  done < <(incus image list -c f --format csv 2>/dev/null)

  uninstall_run incus profile device remove default root
  uninstall_run incus profile device remove default eth0
  uninstall_run incus storage delete default
  uninstall_run incus network delete incusbr0
  [ "${UNINSTALL_DRY_RUN:-0}" = "1" ] && return 0
  # Delete the disk file only when Incus really let go of the pool (never under live data).
  if incus storage show default >/dev/null 2>&1; then
    echo "  ! the storage pool could not be deleted (it still holds data): its disk file was kept"
    return 0
  fi
  rm -f /var/lib/incus/disks/default.img
}
