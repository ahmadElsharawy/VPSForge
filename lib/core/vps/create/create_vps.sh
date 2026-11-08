#!/bin/bash
# Create a VPS. The steps run under run_guarded: if creation fails or is stopped
# at any point (error, Ctrl-C, closed terminal, kill), the half-made VPS is removed
# completely - disk, RAM/CPU limits, IP, SSH port and firewall rules - and the
# reason is shown.
#   create_vps <name> <num> <ram_mb> <port> [ram_mode cpu_mode cpu_value disk_mode disk_value
#               network_mode network_value image traffic_mode rx tx open_ssh]
create_vps() {
  local name="${1:-}" num="${2:-}"
  if ! [[ "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
    echo "ERROR: Invalid VPS name '$name'. Use letters, digits, dots, dashes or underscores (no spaces)."
    return 1
  fi
  [[ "$num" =~ ^[0-9]+$ ]] || { echo "ERROR: Invalid VPS number '$num'."; return 1; }

  local ip="${NETWORK_PREFIX}.$((IP_START + num - 1))" port
  port=$(vps_fixed_port "$num")

  run_guarded "cleanup_failed_vps $name $ip $port" _create_vps_steps "$@"
}
