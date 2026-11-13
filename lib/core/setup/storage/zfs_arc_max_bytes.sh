#!/bin/bash
# Print the ZFS ARC (cache) limit in bytes for a host with <memtotal_kb> of RAM: one eighth of
# the RAM, but never below 64MiB, so ZFS cannot eat the memory of a weak server.
#   zfs_arc_max_bytes <memtotal_kb>
zfs_arc_max_bytes() {
  local kb="${1:-}" bytes min=67108864
  [[ "$kb" =~ ^[0-9]+$ ]] || return 1
  bytes=$((kb * 1024 / 8))
  [ "$bytes" -lt "$min" ] && bytes=$min
  echo "$bytes"
}
