#!/bin/bash
# VPSForge v1.0.0 — Host resource information.

get_host_cpu_count()        { nproc; }
get_host_total_ram_mb()     { awk '/MemTotal/{printf "%d",$2/1024}' /proc/meminfo; }
get_host_available_ram_mb() { awk '/MemAvailable/{printf "%d",$2/1024}' /proc/meminfo; }

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

get_host_disk_total_gb() {
  local path
  path=$(get_incus_pool_path)
  df -BG --output=size "$path" 2>/dev/null | tail -1 | tr -dc '0-9'
}

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

get_total_network_mbit() {
  local saved speed iface
  saved=$(cat /opt/vpsforge/network_speed_mbit 2>/dev/null || true)
  if [[ "$saved" =~ ^[0-9]+$ ]] && [ "$saved" -gt 0 ]; then echo "$saved"; return; fi
  iface=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
  speed=$(cat "/sys/class/net/$iface/speed" 2>/dev/null || true)
  if [[ "$speed" =~ ^[0-9]+$ ]] && [ "$speed" -gt 1000 ]; then
    echo "$speed"
  else
    echo 10000
  fi
}

set_total_network_mbit() {
  local speed="$1"
  mkdir -p /opt/vpsforge 2>/dev/null || true
  echo "$speed" > /opt/vpsforge/network_speed_mbit
}
