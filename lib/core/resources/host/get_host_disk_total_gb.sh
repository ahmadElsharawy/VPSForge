#!/bin/bash
# Returns total disk space in GB of the filesystem hosting the Incus storage pool.
get_host_disk_total_gb() {
  local path
  path=$(get_incus_pool_path)
  df -BG --output=size "$path" 2>/dev/null | tail -1 | tr -dc '0-9'
}
