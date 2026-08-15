#!/bin/bash
# VPSForge v1.0.0 — VPS settings preservation for reinstall/edit.

PRESERVED_RAM_LIMIT=""
PRESERVED_RAM_MODE=""
PRESERVED_CPU_LIMIT=""
PRESERVED_CPU_MODE=""
PRESERVED_DISK_LIMIT=""
PRESERVED_DISK_MODE=""
PRESERVED_NETWORK_LIMIT=""
PRESERVED_NETWORK_MODE=""
PRESERVED_USER=""
PRESERVED_PASSWORD=""

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
}

print_preserved_settings() {
  local name="$1" port="$2"
  echo "Preserving $name settings:"
  echo "  RAM: $PRESERVED_RAM_MODE ${PRESERVED_RAM_LIMIT:+${PRESERVED_RAM_LIMIT}MB}"
  echo "  CPU: $PRESERVED_CPU_MODE ${PRESERVED_CPU_LIMIT:+${PRESERVED_CPU_LIMIT} core(s)}"
  echo "  Disk: $PRESERVED_DISK_MODE ${PRESERVED_DISK_LIMIT:+${PRESERVED_DISK_LIMIT}GB}"
  echo "  Network: $PRESERVED_NETWORK_MODE ${PRESERVED_NETWORK_LIMIT:+${PRESERVED_NETWORK_LIMIT}Mbit}"
  echo "  Port: $port"
}
