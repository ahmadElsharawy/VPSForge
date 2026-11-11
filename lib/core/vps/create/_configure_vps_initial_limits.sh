#!/bin/bash
# Apply initial profiles, devices, resource limits, and traffic modes to an initialized container.
#   _configure_vps_initial_limits <name> <ip> <num> <ram> <ram_mode> <cpu_val> <cpu_mode> <disk_val> <disk_mode> <net_val> <net_mode> <traffic_mode> <traffic_rx> <traffic_tx>
_configure_vps_initial_limits() {
  local name="$1" ip="$2" num="$3"
  local ram="$4" ram_mode="$5" cpu_value="$6" cpu_mode="$7"
  local disk_value="$8" disk_mode="$9" network_value="${10}" network_mode="${11}"
  local traffic_mode="${12}" traffic_rx="${13}" traffic_tx="${14}"

  apply_incus_compatibility_profile "$name" || {
    echo "ERROR: Failed to apply Incus compatibility profile for $name."
    incus delete "$name" --force >/dev/null 2>&1 || true
    return 1
  }

  configure_vps_network_device "$name" "$ip" || {
    echo "ERROR: Failed to configure network device for $name."
    incus delete "$name" --force >/dev/null 2>&1 || true
    return 1
  }

  incus config set "$name" user.vpsforge.ip "$ip" || true
  incus config set "$name" user.vpsforge.num "$num" || true

  _apply_resource_limit "$name" ram  "$ram_mode"     "$ram"           || { _rollback_vps "$name"; return 1; }
  _apply_resource_limit "$name" cpu  "$cpu_mode"     "$cpu_value"     || { _rollback_vps "$name"; return 1; }
  _apply_resource_limit "$name" disk "$disk_mode"    "$disk_value"    || { _rollback_vps "$name"; return 1; }
  _apply_resource_limit "$name" net  "$network_mode" "$network_value" || { _rollback_vps "$name"; return 1; }
  set_traffic_mode_for_vps "$name" "$traffic_mode" "$traffic_rx" "$traffic_tx" >/dev/null 2>&1 || true
}
