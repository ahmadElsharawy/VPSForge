#!/bin/bash
# VPSForge v1.0.0 — Disk resource management.

get_vps_disk_limit_gb() {
  local raw
  raw=$(incus config device get "$1" root size 2>/dev/null || true)
  [ -n "$raw" ] || return 0
  echo "$raw" | awk '
    /GiB$/ {gsub(/GiB/,""); printf "%d",$1; exit}
    /GB$/  {gsub(/GB/,"");  printf "%d",$1; exit}
    /MiB$/ {gsub(/MiB/,""); printf "%d",$1/1024; exit}'
}

get_vps_disk_usage_gb() {
  local bytes=0
  bytes=$(incus query "/1.0/instances/$1/state" </dev/null 2>/dev/null | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    disk = data.get("disk", {})
    usage = 0
    for dev, info in disk.items():
        if isinstance(info, dict):
            u = info.get("usage", 0)
            if u and int(u) > usage:
                usage = int(u)
    print(usage)
except Exception:
    print(0)
' 2>/dev/null || echo 0)

  if [ -z "$bytes" ] || [ "$bytes" -eq 0 ] 2>/dev/null; then
    bytes=$(incus exec "$1" -- sh -c 'du -s -B1 --exclude=/proc --exclude=/sys --exclude=/dev / 2>/dev/null | awk "{print \$1}"' </dev/null 2>/dev/null || echo 0)
  fi

  [[ "$bytes" =~ ^[0-9]+$ ]] || bytes=0
  awk -v b="$bytes" 'BEGIN {printf "%.1f", b/1073741824}'
}

format_disk_display() {
  local name="$1" used limit
  used=$(get_vps_disk_usage_gb "$name")
  limit=$(get_vps_disk_limit_gb "$name")
  if [ -n "$limit" ] && [ "$limit" -gt 0 ] 2>/dev/null; then
    echo "${used}GB / ${limit}GB"
  else
    echo "${used}GB / $(get_host_disk_available_gb)GB"
  fi
}

set_disk_mode_for_vps() {
  local name="$1" mode="$2" value="${3:-}" max min_disk=3 actual
  max=$(get_host_disk_available_gb)
  ensure_device_override "$name" root || return 1

  case "$mode" in
    unlimited)
      incus config device unset "$name" root size 2>/dev/null || true
      ;;
    limited)
      [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge "$min_disk" ] && [ "$value" -le "$max" ] || {
        echo "ERROR: Disk limit must be between ${min_disk}GB and ${max}GB (available)."
        return 1
      }
      incus config device set "$name" root size "${value}GiB" || return 1
      actual=$(incus config device get "$name" root size 2>/dev/null || true)
      [ "$actual" = "${value}GiB" ] || {
        echo "ERROR: Disk verification failed for $name. Requested=${value}GiB Actual=${actual:-none}"
        return 1
      }
      ;;
    *) return 1;;
  esac
}

ask_disk_mode() {
  local c v total available min_disk=3
  total=$(get_host_disk_total_gb)
  available=$(get_host_disk_available_gb)
  while :; do
    echo "----------------------------------------------------------------"
    echo "Disk Mode for $1:"
    echo "Total Disk: ${total}GB | Available: ${available}GB"
    echo "0) Back"
    echo "1) Unlimited (Default)"
    echo "2) Set Disk Limit (Minimum ${min_disk}GB)"
    read -r -p "Choice [0=Back, Enter=1]: " c
    c="${c:-1}"
    case "$c" in
      0) return 1;;
      1) DISK_MODE_RESULT="unlimited"; DISK_VALUE_RESULT=""; return 0;;
      2)
        while :; do
          read -r -p "Disk Limit in GB (minimum ${min_disk}GB, up to ${available}GB, or 0 to back): " v
          [ "${v:-}" = "0" ] && continue 2
          if [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -ge "$min_disk" ] && [ "$v" -le "$available" ]; then
            DISK_MODE_RESULT="limited"; DISK_VALUE_RESULT="$v"
            return 0
          fi
          echo "ERROR: Disk limit must be between ${min_disk}GB and ${available}GB (available on host)."
        done
        ;;
      *) echo "Invalid choice.";;
    esac
  done
}
