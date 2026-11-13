#!/bin/bash
# Succeeds when this host can use ZFS pools (the zpool tool exists and the kernel module loads).
zfs_is_available() {
  command -v zpool >/dev/null 2>&1 && modprobe zfs >/dev/null 2>&1
}
