#!/bin/bash
# Execute the sequential steps to create and configure a new VPS container.
_create_vps_steps() {
  local name="$1" num="$2" ram="$3" port="$4"
  local ram_mode="${5:-limited}" cpu_mode="${6:-unlimited}" cpu_value="${7:-}"
  local disk_mode="${8:-unlimited}" disk_value="${9:-}"
  local network_mode="${10:-unlimited}" network_value="${11:-}"
  local image="${12:-$VPS_IMAGE}"
  local traffic_mode="${13:-unlimited}" traffic_rx="${14:-0}" traffic_tx="${15:-0}"
  local open_ssh="${16:-y}"
  local ip="${VPS_FORCE_IP:-${NETWORK_PREFIX}.$((IP_START+num-1))}"

  image=$(normalize_image_alias "$image")
  port="${VPS_FORCE_PORT:-$(vps_fixed_port "$num")}"
  check_fixed_port_available "$name" "$ip" "$port" || return 1
  pending_operation_set "$name" "$ip" "$port"

  local ram_label cpu_label
  [ "$ram_mode" = "unlimited" ] && ram_label="Unlimited" || ram_label="${ram}MB"
  [ "$cpu_mode" = "unlimited" ] && cpu_label="$(get_host_cpu_count) Core(s)" || cpu_label="${cpu_value} Core(s)"
  echo "Creating $name | Target Image: $image | RAM $ram_label | CPU $cpu_label | IP $ip | Port $port"

  _init_vps_instance "$name" "$image" || return 1
  mark_vps_state "$name" creating

  _configure_vps_initial_limits "$name" "$ip" "$num" "$ram" "$ram_mode" "$cpu_value" "$cpu_mode" \
    "$disk_value" "$disk_mode" "$network_value" "$network_mode" "$traffic_mode" "$traffic_rx" "$traffic_tx" || return 1

  # The VPS was only created (not started) so devices and limits apply cleanly; start it now.
  incus start "$name" || {
    echo "ERROR: Failed to start $name."
    _rollback_vps "$name"
    return 1
  }

  set_vps_saved_port "$name" "$port"

  wait_ready "$name" || {
    echo "$name failed to become ready. Reserved port: $port"
    _rollback_vps "$name"
    return 1
  }

  wait_guest_eth0 "$name" || {
    echo "ERROR: eth0 did not appear inside $name."
    diagnose_guest_network "$name" "$ip"
    _rollback_vps "$name"
    return 1
  }

  _setup_guest_networking "$name" "$ip" "$port" || return 1

  echo "Installing and configuring SSH in $name..."
  _install_ssh "$name" "$ip" "$port" || return 1

  _configure_guest_optimizations "$name"
  _finalize_vps_access "$name" "$ip" "$port" "$open_ssh"
}
