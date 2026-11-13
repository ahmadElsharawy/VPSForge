#!/bin/bash
# Print the storage driver (zfs, btrfs, dir...) of the Incus pool <name> (default: "default").
#   get_pool_driver [name]
get_pool_driver() {
  local name="${1:-default}"
  incus storage show "$name" 2>/dev/null | awk '/^driver:/{print $2; exit}'
}
