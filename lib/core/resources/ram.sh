#!/bin/bash
# VPSForge v1.0.0 — RAM resource management.

get_vps_ram_limit_mb() {
  local raw
  raw=$(incus config get "$1" limits.memory 2>/dev/null || true)
  [ -n "$raw" ] || return 0
  ram_mb "$raw"
}

get_vps_ram_usage_mb() {
  local bytes
  bytes=$(incus query "/1.0/instances/$1/state" 2>/dev/null |
    python3 -c 'import sys,json; print(json.load(sys.stdin).get("memory",{}).get("usage",0))' 2>/dev/null || echo 0)
  [[ "$bytes" =~ ^[0-9]+$ ]] || bytes=0
  echo $((bytes / 1024 / 1024))
}

format_ram_display() {
  local name="$1" used limit
  used=$(get_vps_ram_usage_mb "$name")
  limit=$(get_vps_ram_limit_mb "$name")
  if [ -n "$limit" ] && [ "$limit" -gt 0 ] 2>/dev/null; then
    echo "${used}MB / ${limit}MB"
  else
    echo "${used}MB / $(get_host_available_ram_mb)MB"
  fi
}

set_ram_mode_for_vps() {
  local name="$1" mode="$2" value="${3:-}" actual
  case "$mode" in
    unlimited)
      incus config unset "$name" limits.memory 2>/dev/null || true
      actual=$(incus config get "$name" limits.memory 2>/dev/null || true)
      [ -z "$actual" ] || {
        echo "ERROR: Failed to remove RAM limit from $name."
        return 1
      }
      ;;
    limited)
      [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge "$MIN_RAM_MB" ] || {
        echo "ERROR: Invalid RAM limit: $value MB."
        return 1
      }
      incus config set "$name" limits.memory "${value}MiB" || return 1
      actual=$(incus config get "$name" limits.memory 2>/dev/null || true)
      [ "$(ram_mb "$actual")" = "$value" ] || {
        echo "ERROR: RAM verification failed for $name. Requested=${value}MB Actual=${actual:-none}"
        return 1
      }
      ;;
    *) return 1;;
  esac
}

ask_ram_mode() {
  local c v
  while :; do
    echo "----------------------------------------------------------------"
    echo "RAM Mode for $1:"
    echo "Total RAM: $(get_host_total_ram_mb)MB | Available: $(get_host_available_ram_mb)MB"
    echo "0) Back"
    echo "1) Unlimited (Default)"
    echo "2) Set RAM Limit"
    read -r -p "Choice [0=Back, Enter=1]: " c
    c="${c:-1}"
    case "$c" in
      0) return 1;;
      1) RAM_MODE_RESULT="unlimited"; RAM_VALUE_RESULT=""; return 0;;
      2)
        while :; do
          read -r -p "RAM Limit in MB (minimum $MIN_RAM_MB, or 0 to back): " v
          [ "${v:-}" = "0" ] && continue 2
          if [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -ge "$MIN_RAM_MB" ]; then
            RAM_MODE_RESULT="limited"; RAM_VALUE_RESULT="$v"
            return 0
          fi
          echo "Invalid RAM limit."
        done
        ;;
      *) echo "Invalid choice.";;
    esac
  done
}
