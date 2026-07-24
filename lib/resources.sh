#!/bin/bash
# VPSForge — Resource management: RAM, CPU, Disk, Network.

# ── Host Info ────────────────────────────────────────────────────────────────

get_host_cpu_count()        { nproc; }
get_host_total_ram_mb()     { awk '/MemTotal/{printf "%d",$2/1024}' /proc/meminfo; }
get_host_available_ram_mb() { awk '/MemAvailable/{printf "%d",$2/1024}' /proc/meminfo; }
get_host_disk_total_gb()    { df -BG --output=size / | tail -1 | tr -dc '0-9'; }
get_host_disk_available_gb(){ df -BG --output=avail / | tail -1 | tr -dc '0-9'; }

get_total_network_mbit() {
  local saved speed iface
  saved=$(cat /opt/vpsforge/network_speed_mbit 2>/dev/null || true)
  if [[ "$saved" =~ ^[0-9]+$ ]] && [ "$saved" -gt 0 ]; then echo "$saved"; return; fi
  iface=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
  speed=$(cat "/sys/class/net/$iface/speed" 2>/dev/null || true)
  if [[ "$speed" =~ ^[0-9]+$ ]] && [ "$speed" -gt 0 ]; then echo "$speed"; else echo 1000; fi
}

# ── Total Allocated RAM ─────────────────────────────────────────────────────

total_allocated() {
  local t=0 n r
  while read -r n; do
    [ -z "$n" ] && continue
    r=$(ram_mb "$(get_ram "$n")")
    [[ "$r" =~ ^[0-9]+$ ]] && t=$((t+r))
  done < <(incus list -c n --format csv | grep -E "^${VPS_PREFIX}[0-9]+$" || true)
  echo "$t"
}

# ── Incus Device Override ────────────────────────────────────────────────────

# Creates a per-instance override for an inherited Incus device if it does not
# already exist in the instance's local config.
ensure_device_override() {
  local name="$1" device="$2"

  if incus config show "$name" 2>/dev/null | awk '
      /^devices:/ {in_devices=1; next}
      in_devices && /^[^ ]/ {in_devices=0}
      in_devices && $0 ~ "^  '"$device"':$" {found=1}
      END {exit !found}
    '; then
    return 0
  fi

  incus config device override "$name" "$device" || {
    echo "ERROR: Failed to override device $device for $name."
    return 1
  }
}

# ── RAM ──────────────────────────────────────────────────────────────────────

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
  echo "RAM Mode for $1:"
  echo "Total RAM: $(get_host_total_ram_mb)MB | Available: $(get_host_available_ram_mb)MB"
  echo "1) Unlimited"
  echo "2) Set RAM Limit"
  read -r -p "Choice: " c
  case "$c" in
    1) RAM_MODE_RESULT="unlimited"; RAM_VALUE_RESULT="";;
    2)
      while :; do
        read -r -p "RAM Limit in MB (minimum $MIN_RAM_MB): " v
        [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -ge "$MIN_RAM_MB" ] && break
        echo "Invalid RAM limit."
      done
      RAM_MODE_RESULT="limited"; RAM_VALUE_RESULT="$v"
      ;;
    *) echo "Invalid choice."; return 1;;
  esac
}

# ── CPU ──────────────────────────────────────────────────────────────────────

get_vps_cpu_limit() {
  local configured
  configured=$(incus config get "$1" limits.cpu 2>/dev/null || true)
  if [ -n "$configured" ]; then
    echo "$configured"
  else
    get_host_cpu_count
  fi
}

set_cpu_mode_for_vps() {
  local name="$1" mode="$2" value="${3:-}" max actual
  max=$(get_host_cpu_count)
  case "$mode" in
    unlimited)
      incus config unset "$name" limits.cpu 2>/dev/null || true
      ;;
    limited)
      [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge 1 ] && [ "$value" -le "$max" ] || {
        echo "ERROR: CPU limit must be between 1 and $max."
        return 1
      }
      incus config set "$name" limits.cpu "$value" || return 1
      actual=$(incus config get "$name" limits.cpu 2>/dev/null || true)
      [ "$actual" = "$value" ] || {
        echo "ERROR: CPU verification failed for $name."
        return 1
      }
      ;;
    *) return 1;;
  esac
}

ask_cpu_mode() {
  local c v max
  max=$(get_host_cpu_count)
  echo "CPU Mode for $1:"
  echo "1) Unlimited (all $max core(s))"
  echo "2) Set CPU Limit"
  read -r -p "Choice: " c
  case "$c" in
    1) CPU_MODE_RESULT="unlimited"; CPU_VALUE_RESULT="";;
    2)
      while :; do
        read -r -p "CPU Cores (1-$max): " v
        [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -ge 1 ] && [ "$v" -le "$max" ] && break
        echo "ERROR: Server has only $max CPU core(s). Allowed range: 1-$max."
      done
      CPU_MODE_RESULT="limited"; CPU_VALUE_RESULT="$v"
      ;;
    *) echo "Invalid choice."; return 1;;
  esac
}

# ── Disk ─────────────────────────────────────────────────────────────────────

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
  local bytes
  bytes=$(incus exec "$1" -- df -B1 --output=used / 2>/dev/null | tail -1 | tr -dc '0-9')
  [[ "$bytes" =~ ^[0-9]+$ ]] || bytes=0
  awk -v b="$bytes" 'BEGIN {printf "%.1f", b/1073741824}'
}

format_disk_display() {
  local name="$1" used limit
  used=$(get_vps_disk_usage_gb "$name")
  limit=$(get_vps_disk_limit_gb "$name")
  if [ -n "$limit" ]; then
    echo "${used}GB / ${limit}GB"
  else
    echo "${used}GB / $(get_host_disk_available_gb)GB"
  fi
}

set_disk_mode_for_vps() {
  local name="$1" mode="$2" value="${3:-}" max actual
  max=$(get_host_disk_total_gb)
  ensure_device_override "$name" root || return 1

  case "$mode" in
    unlimited)
      incus config device unset "$name" root size 2>/dev/null || true
      ;;
    limited)
      [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge 1 ] && [ "$value" -le "$max" ] || {
        echo "ERROR: Disk limit must be between 1GB and ${max}GB."
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
  local c v total available
  total=$(get_host_disk_total_gb)
  available=$(get_host_disk_available_gb)
  echo "Disk Mode for $1:"
  echo "Total Disk: ${total}GB | Available: ${available}GB"
  echo "1) Unlimited"
  echo "2) Set Disk Limit"
  read -r -p "Choice: " c
  case "$c" in
    1) DISK_MODE_RESULT="unlimited"; DISK_VALUE_RESULT="";;
    2)
      while :; do
        read -r -p "Disk Limit in GB (1-${total}): " v
        [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -ge 1 ] && [ "$v" -le "$total" ] && break
        echo "Invalid disk limit."
      done
      DISK_MODE_RESULT="limited"; DISK_VALUE_RESULT="$v"
      ;;
    *) return 1;;
  esac
}

# ── Network Speed ────────────────────────────────────────────────────────────

get_vps_network_io_display() {
  local name="$1"
  incus query "/1.0/instances/$name/state" 2>/dev/null | python3 -c '
import sys, json

def human_bytes(b):
    if b >= 1073741824: return f"{b/1073741824:.1f}G"
    if b >= 1048576:    return f"{b/1048576:.1f}M"
    if b >= 1024:       return f"{b/1024:.0f}K"
    return f"{b}B"

try:
    data = json.load(sys.stdin)
    eth0 = data.get("network", {}).get("eth0", {})
    counters = eth0.get("counters", {})
    rx = int(counters.get("bytes_received", 0))
    tx = int(counters.get("bytes_sent", 0))
    print(f"↓{human_bytes(rx)} ↑{human_bytes(tx)}")
except Exception:
    print("-")
' || echo "-"
}

format_network_display() {
  local name="$1" limit io
  limit=$(get_vps_network_limit_mbit "$name" 2>/dev/null || true)
  io=$(get_vps_network_io_display "$name" 2>/dev/null || echo "-")
  if [ -n "$limit" ]; then
    echo "${limit}M [${io}]"
  else
    local max
    max=$(get_total_network_mbit 2>/dev/null || echo 1000)
    echo "${max}M [${io}]"
  fi
}


set_network_mode_for_vps() {
  local name="$1" mode="$2" value="${3:-}" max actual_in actual_out
  max=$(get_total_network_mbit)
  ensure_device_override "$name" eth0 || return 1

  case "$mode" in
    unlimited)
      incus config device unset "$name" eth0 limits.ingress 2>/dev/null || true
      incus config device unset "$name" eth0 limits.egress  2>/dev/null || true
      ;;
    limited)
      [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge 1 ] && [ "$value" -le "$max" ] || {
        echo "ERROR: Network limit must be between 1 and $max Mbit."
        return 1
      }
      incus config device set "$name" eth0 limits.ingress "${value}Mbit" || return 1
      incus config device set "$name" eth0 limits.egress  "${value}Mbit" || return 1

      actual_in=$(incus config device get "$name" eth0 limits.ingress 2>/dev/null || true)
      actual_out=$(incus config device get "$name" eth0 limits.egress 2>/dev/null || true)
      [ "$actual_in" = "${value}Mbit" ] && [ "$actual_out" = "${value}Mbit" ] || {
        echo "ERROR: Network verification failed for $name."
        return 1
      }
      ;;
    *) return 1;;
  esac
}

ask_network_mode() {
  local c v max
  max=$(get_total_network_mbit)
  echo "Network Mode for $1:"
  echo "Total Network Speed: ${max} Mbit"
  echo "1) Unlimited"
  echo "2) Set Speed Limit"
  read -r -p "Choice: " c
  case "$c" in
    1) NETWORK_MODE_RESULT="unlimited"; NETWORK_VALUE_RESULT="";;
    2)
      while :; do
        read -r -p "Network Limit in Mbit (1-${max}): " v
        [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -ge 1 ] && [ "$v" -le "$max" ] && break
        echo "Invalid network limit."
      done
      NETWORK_MODE_RESULT="limited"; NETWORK_VALUE_RESULT="$v"
      ;;
    *) return 1;;
  esac
}
