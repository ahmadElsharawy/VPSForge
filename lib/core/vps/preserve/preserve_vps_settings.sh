#!/bin/bash
preserve_vps_settings() {
  local name="$1"

  PRESERVED_RAM_LIMIT=$(get_vps_ram_limit_mb "$name")
  PRESERVED_CPU_LIMIT=$(incus config get "$name" limits.cpu 2>/dev/null || true)
  PRESERVED_DISK_LIMIT=$(get_vps_disk_limit_gb "$name")
  PRESERVED_NETWORK_LIMIT=$(get_vps_network_limit_mbit "$name")

  if [ -n "$PRESERVED_RAM_LIMIT" ]; then
    PRESERVED_RAM_MODE="limited"
  else
    PRESERVED_RAM_MODE="unlimited"
    PRESERVED_RAM_LIMIT="$MIN_RAM_MB"
  fi

  PRESERVED_CPU_MODE="unlimited"
  [ -n "$PRESERVED_CPU_LIMIT" ] && PRESERVED_CPU_MODE="limited"

  PRESERVED_DISK_MODE="unlimited"
  [ -n "$PRESERVED_DISK_LIMIT" ] && PRESERVED_DISK_MODE="limited"

  PRESERVED_NETWORK_MODE="unlimited"
  [ -n "$PRESERVED_NETWORK_LIMIT" ] && PRESERVED_NETWORK_MODE="limited"

  PRESERVED_USER=$(get_vps_user "$name")
  PRESERVED_PASSWORD=$(get_vps_password "$name")
  PRESERVED_TUNNELS=$(incus config get "$name" user.vpsforge.tunnels 2>/dev/null || true)
}
