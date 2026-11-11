#!/bin/bash
# Repairs SSH access, IP conflicts, and firewall port forwarding for a single VPS.
_repair_single_vps() {
  local n="$1"
  local num ip preferred
  num=$(get_num "$n")
  ip=$(get_ip "$n")
  preferred=$(get_vps_saved_port "$n" 2>/dev/null || true)   # keep a port the owner changed
  [[ "$preferred" =~ ^[0-9]+$ ]] || preferred=$(vps_fixed_port "$num")
  if ! check_fixed_port_available "$n" "$ip" "$preferred"; then
    echo "FAILED: $n requires fixed port $preferred."
    return 1
  fi

  if repair_vps_connection "$n" "$preferred" </dev/null; then
    set_vps_saved_port "$n" "$preferred"
    return 0
  else
    return 1
  fi
}
