#!/bin/bash
# Settings action: move every VPS to a ZFS storage pool, so inside a VPS "df" shows only that
# VPS's own disk limit. Explains what happens, asks for confirmation, then runs the safe
# migration (a stopped migration is finished by the next VPSForge start).
move_vps_to_zfs_menu() {
  local answer before after
  if [ "$(get_pool_driver default)" = "zfs" ]; then
    echo "The storage pool already uses ZFS."
    return 0
  fi
  if ! command -v zpool >/dev/null 2>&1; then
    read -r -p "ZFS tools are not installed. Install zfsutils-linux now? [y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]] || { echo "Cancelled."; return 0; }
    vpsforge_apt_install zfsutils-linux || { echo "ERROR: could not install zfsutils-linux."; return 1; }
  fi
  if ! zfs_is_available; then
    echo "ERROR: this server's kernel cannot use ZFS."
    return 1
  fi

  echo "Every VPS will be STOPPED, moved to a new ZFS storage pool, and started again."
  echo "Disk limits, snapshots and settings are kept. It can take several minutes."
  echo "If a VPS cannot be moved, everything is put back and nothing is deleted."
  read -r -p "Move all VPSs to ZFS storage now? [y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]] || { echo "Cancelled."; return 0; }

  rm -f /opt/vpsforge/.pool_migration_failed   # an earlier failed attempt must not block this one
  before=$(_zfs_move_root_sizes)
  migrate_default_pool zfs
  if [ "$(get_pool_driver default)" != "zfs" ]; then
    echo "The move did not finish. Read the messages above; VPSForge continues it at the next start if it was interrupted."
    return 1
  fi
  after=$(_zfs_move_root_sizes)
  if [ "$before" != "$after" ]; then
    echo "WARNING: some VPS disk limits changed during the move. Check them in the Resources menu."
  fi
  echo "Done: every VPS now shows only its own disk size."
  return 0
}
