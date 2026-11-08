#!/bin/bash
# Returns the filesystem path where Incus actually stores container data.
get_incus_pool_path() {
  local pool
  pool=$(incus profile device get default root pool 2>/dev/null || true)
  [ -n "$pool" ] || pool="default"
  
  if [ -d "/var/lib/incus/storage-pools/$pool" ]; then
    echo "/var/lib/incus/storage-pools/$pool"
    return
  fi
  if [ -d "/var/lib/lxd/storage-pools/$pool" ]; then
    echo "/var/lib/lxd/storage-pools/$pool"
    return
  fi

  local pool_source
  pool_source=$(incus storage show "$pool" 2>/dev/null | \
    awk -F': ' '/^[[:space:]]*source:/{print $2; exit}')
  if [ -n "$pool_source" ] && [ -d "$pool_source" ]; then
    echo "$pool_source"
    return
  fi
  for d in /var/lib/incus /var/lib/lxd /; do
    [ -d "$d" ] && { echo "$d"; return; }
  done
  echo "/"
}
