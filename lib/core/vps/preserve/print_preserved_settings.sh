#!/bin/bash
# Print preserved resource limits, disk, CPU, RAM, network, and SSH port for a VPS.
print_preserved_settings() {
  local name="$1" port="$2"
  echo "Preserving $name settings:"
  echo "  RAM: $PRESERVED_RAM_MODE ${PRESERVED_RAM_LIMIT:+${PRESERVED_RAM_LIMIT}MB}"
  echo "  CPU: $PRESERVED_CPU_MODE ${PRESERVED_CPU_LIMIT:+${PRESERVED_CPU_LIMIT} core(s)}"
  echo "  Disk: $PRESERVED_DISK_MODE ${PRESERVED_DISK_LIMIT:+${PRESERVED_DISK_LIMIT}GB}"
  echo "  Network: $PRESERVED_NETWORK_MODE ${PRESERVED_NETWORK_LIMIT:+${PRESERVED_NETWORK_LIMIT}Mbit}"
  echo "  Port: $port"
}
