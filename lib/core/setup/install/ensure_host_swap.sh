#!/bin/bash
# Weak hosts (under 2GB RAM) with no swap get a swap file, so several VPSs can
# run without the kernel killing them. Skipped when swap already exists or the
# disk is too small to spare the space.
ensure_host_swap() {
  local ram_mb swap_kb free_gb size_mb swapfile="$SWAPFILE_PATH"

  ram_mb=$(get_host_total_ram_mb 2>/dev/null || echo 0)
  swap_kb=$(awk '/SwapTotal/{print $2}' /proc/meminfo 2>/dev/null || echo 0)

  [ "${ram_mb:-0}" -gt 0 ] && [ "$ram_mb" -lt 2048 ] || return 0
  [ "${swap_kb:-0}" -eq 0 ] || return 0
  [ ! -e "$swapfile" ] || return 0

  free_gb=$(df -BG --output=avail / 2>/dev/null | tail -1 | tr -dc '0-9')
  [ "${free_gb:-0}" -ge 6 ] || return 0

  size_mb=2048
  [ "$ram_mb" -ge 1024 ] && size_mb=1024

  echo "Low-memory host (${ram_mb}MB RAM, no swap): creating ${size_mb}MB swap file..." >&2
  if ! { fallocate -l "${size_mb}M" "$swapfile" 2>/dev/null || dd if=/dev/zero of="$swapfile" bs=1M count="$size_mb" status=none; }; then
    rm -f "$swapfile"
    return 0
  fi
  chmod 600 "$swapfile"
  mkswap "$swapfile" >/dev/null 2>&1 && swapon "$swapfile" 2>/dev/null || { rm -f "$swapfile"; return 0; }
  grep -q "$swapfile" /etc/fstab 2>/dev/null || echo "$swapfile none swap sw 0 0" >> /etc/fstab
}
