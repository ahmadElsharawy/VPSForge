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
  if incus info "$name" >/dev/null 2>&1; then
    echo "ERROR: A VPS named '$name' already exists. Choose another name."
    return 1
  fi

  # VPS_FORCE_IP / VPS_FORCE_PORT: a reinstall keeps the address and SSH port the VPS already had.
  local ip="${VPS_FORCE_IP:-${NETWORK_PREFIX}.$((IP_START + num - 1))}" port
  port="${VPS_FORCE_PORT:-$(vps_fixed_port "$num")}"

  # A reinstall keeps its own address; every other create must pick one nobody holds (one look at Incus).
  if [ -z "${VPS_FORCE_IP:-}" ] && vps_inventory 2>/dev/null | awk -F'|' -v ip="$ip" '$2 == ip { f = 1 } END { exit !f }'; then
    echo "ERROR: the address $ip is already used by another VPS. Nothing was created."
    return 1
  fi

  run_guarded "cleanup_failed_vps $name $ip $port" _create_vps_steps "$@"
}
