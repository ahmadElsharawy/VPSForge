#!/bin/bash
# Returns host available disk minus disk already reserved by VPS limits.
get_host_disk_available_gb() {
  local path raw_avail allocated net
  path=$(get_incus_pool_path)
  raw_avail=$(df -BG --output=avail "$path" 2>/dev/null | tail -1 | tr -dc '0-9')
  allocated=$(total_allocated_disk_gb 2>/dev/null || echo 0)
  [[ "$raw_avail" =~ ^[0-9]+$ ]] || raw_avail=0
  [[ "$allocated" =~ ^[0-9]+$ ]] || allocated=0
  net=$(( raw_avail - allocated ))
  [ "$net" -lt 0 ] && net=0
  echo "$net"
}
