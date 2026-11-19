#!/bin/bash
# Print preserved resource limits, disk, CPU, RAM, network, and SSH port for a VPS.
print_preserved_settings() {
  local name="$1" port="$2"
  echo "Preserving $name settings:"
  if [ "$PRESERVED_RAM_MODE" = "unlimited" ]; then echo "  RAM: unlimited"; else echo "  RAM: ${PRESERVED_RAM_LIMIT}MB"; fi
  split_cpu_value "$PRESERVED_CPU_LIMIT"
  local cpu_str="$PRESERVED_CPU_MODE"
  [ -n "$CPU_CORES_PART" ] && cpu_str="$cpu_str ${CPU_CORES_PART} core(s)"
  [ -n "$CPU_ALLOWANCE_PART" ] && cpu_str="$cpu_str, ${CPU_ALLOWANCE_PART}% cap"
  echo "  CPU: $cpu_str"
  echo "  Disk: $PRESERVED_DISK_MODE ${PRESERVED_DISK_LIMIT:+${PRESERVED_DISK_LIMIT}GB}"
  echo "  Network: $PRESERVED_NETWORK_MODE ${PRESERVED_NETWORK_LIMIT:+${PRESERVED_NETWORK_LIMIT}Mbit}"
  echo "  Port: $port"
}
