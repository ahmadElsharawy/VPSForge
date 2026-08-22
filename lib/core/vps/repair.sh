#!/bin/bash
# VPSForge v1.0.0 — VPS connection repair.

repair_vps_connection() {
  local name="$1" ip port reachable=0

  is_vps_running "$name" || incus start "$name"
  wait_ready "$name" || { echo "FAILED: $name did not become ready."; return 1; }

  apply_incus_compatibility_profile "$name" || echo "WARNING: could not refresh compatibility profile for $name."
  incus restart "$name" || true
  wait_ready "$name" || { echo "FAILED: $name did not become ready after profile refresh."; return 1; }
  _configure_guest_optimizations "$name"

  ip=$(get_ip "$name")
  [ -n "$ip" ] || { echo "FAILED: No IPv4 for $name."; return 1; }

  echo "Applying static network config inside guest..."
  apply_guest_static_network "$name" "$ip" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}" || {
    echo "WARNING: Failed to apply guest static network config."
  }
  configure_guest_dns "$name" || true
  set_guest_hostname "$name"

  port=$(vps_fixed_port "$(get_num "$name")")
  check_fixed_port_available "$name" "$ip" "$port" || return 1
  set_vps_saved_port "$name" "$port"

  ensure_ssh_ready "$name" || { echo "FAILED: SSH could not start in $name."; return 1; }

  local i
  for i in $(seq 1 15); do
    timeout 2 bash -c "</dev/tcp/$ip/22" >/dev/null 2>&1 && { reachable=1; break; }
    sleep 1
  done
  [ "$reachable" -eq 1 ] || { echo "FAILED: Host cannot reach $ip:22."; return 1; }

  add_forward_rule "$ip" "$port"
  echo "OK: $name | $PUBLIC_IP:$port -> $ip:22"
}
