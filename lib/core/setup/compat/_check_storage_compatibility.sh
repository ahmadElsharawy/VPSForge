#!/bin/bash
_check_storage_compatibility() {
  local pool pool_source fstype

  pool=$(incus profile device get default root pool 2>/dev/null || true)
  [ -n "$pool" ] || pool="default"
  pool_source=$(incus storage show "$pool" 2>/dev/null | awk -F': ' '/^[[:space:]]*source:/{print $2; exit}')
  [ -n "$pool_source" ] && [ -e "$pool_source" ] || pool_source="/var/lib/incus/storage-pools/${pool}"

  [ -e "$pool_source" ] || return 0

  fstype=$(stat -f -c %T "$pool_source" 2>/dev/null || echo "unknown")

  if [[ "$fstype" == *overlay* ]]; then
    echo "  [MISSING] The Incus storage pool '$pool' ($pool_source) sits on an OVERLAYFS backing filesystem."
    echo "            Docker's overlay2 driver does not support running overlay-on-overlay (official Docker limitation)."
    echo "            Fix on host: provision the Incus storage pool on ext4, xfs (ftype=1), btrfs, or zfs instead."
    issues=$((issues+1))
  elif [[ "$fstype" == *xfs* ]]; then
    if command -v xfs_info >/dev/null 2>&1; then
      local ftype
      ftype=$(xfs_info "$pool_source" 2>/dev/null | grep -oE 'ftype=[01]' | cut -d= -f2)
      if [ "$ftype" = "0" ]; then
        echo "  [MISSING] The Incus storage pool '$pool' ($pool_source) is on XFS with ftype=0 (d_type disabled)."
        echo "            Docker's overlay2 driver refuses to run without d_type support."
        echo "            Fix on host: reformat with 'mkfs.xfs -n ftype=1' and recreate the storage pool."
        issues=$((issues+1))
      fi
    else
      echo "  [WARNING] Storage pool '$pool' is on XFS but 'xfs_info' is not installed, so ftype=1 support could not be verified."
      echo "            Install xfsprogs on the host and run: xfs_info $pool_source"
    fi
  fi
}
