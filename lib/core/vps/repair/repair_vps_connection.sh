#!/bin/bash
# Repair VPS connectivity, guest network configuration, SSH daemon, and firewall forwards.
repair_vps_connection() {
  local name="$1" ip port
  is_vps_running "$name" || incus start "$name"
  wait_ready "$name" || { echo "FAILED: $name did not become ready."; return 1; }

  apply_incus_compatibility_profile "$name" || echo "WARNING: could not refresh compatibility profile for $name."
  incus restart "$name" || true
  wait_ready "$name" || { echo "FAILED: $name did not become ready after profile refresh."; return 1; }
  _configure_guest_optimizations "$name"

  ip=$(get_ip "$name")
  [ -n "$ip" ] || { echo "FAILED: No IPv4 for $name."; return 1; }

  configure_vps_network_device "$name" "$ip" || true

  echo "Applying static network config inside guest..."
  apply_guest_static_network "$name" "$ip" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}" || {
    echo "WARNING: Failed to apply guest static network config."
  }
  configure_guest_dns "$name" || true
  set_guest_hostname "$name"

  port=$(get_vps_saved_port "$name" 2>/dev/null || true)   # keep a port the owner changed
  [[ "$port" =~ ^[0-9]+$ ]] || port=$(vps_fixed_port "$(get_num "$name")")
  check_fixed_port_available "$name" "$ip" "$port" || return 1
  set_vps_saved_port "$name" "$port"

  ensure_ssh_ready "$name" || { echo "FAILED: SSH could not start in $name."; return 1; }

  _wait_for_ssh_port "$ip" || { echo "FAILED: Host cannot reach $ip:22."; return 1; }

  vps_ssh_forward_enabled "$name" && add_forward_rule "$ip" "$port"
  if vps_ssh_forward_enabled "$name"; then
    echo "OK: $name | $PUBLIC_IP:$port -> $ip:22"
  else
    echo "OK: $name | $ip:22 (no public SSH forward, as created)"
  fi
}
