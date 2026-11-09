#!/bin/bash
# The actual creation steps. Always call create_vps (it guards these steps and cleans up on failure).
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

  local launch_ok=0 launched_image=""
  local -a candidates=()
  mapfile -t candidates < <(resolve_image_candidates "$image")

  for cand in "${candidates[@]}"; do
    [ -n "$cand" ] || continue
    echo "Launching $name with image ($cand)..."
    if incus init "$cand" "$name" 2>/dev/null; then
      launch_ok=1
      launched_image="$cand"
      break
    fi
  done

  if [ "$launch_ok" -eq 0 ]; then
    echo "Attempting fallback with detailed output..."
    for cand in "${candidates[@]}"; do
      [ -n "$cand" ] || continue
      if incus init "$cand" "$name"; then
        launch_ok=1
        launched_image="$cand"
        break
      fi
    done
  fi

  if [ "$launch_ok" -eq 0 ]; then
    echo "ERROR: Failed to launch $name using image '$image' or available fallback images on Incus." >&2
    return 1
  fi

  # Mark it unfinished: if anything stops from here on, startup recovery removes it completely.
  mark_vps_state "$name" creating
  incus config set "$name" user.vpsforge.image "$launched_image" || true

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

  echo "Applying guest network config in $name..."
  apply_guest_static_network "$name" "$ip" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}" || {
    echo "ERROR: Failed to apply guest network config for $name."
    diagnose_guest_network "$name" "$ip"
    _rollback_vps_full "$name" "$ip" "$port"
    return 1
  }

  configure_guest_dns "$name" || {
    echo "ERROR: Failed to configure guest DNS for $name."
    diagnose_guest_network "$name" "$ip"
    _rollback_vps_full "$name" "$ip" "$port"
    return 1
  }

  # Some systems (Alpine's dhcpcd) rewrite DNS a moment after boot: re-apply it a few times before giving up.
  local net_try=0
  until guest_network_config_ok "$name" "$ip" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}" || [ "$net_try" -ge 4 ]; do
    net_try=$((net_try + 1))
    sleep 3
    configure_guest_dns "$name" >/dev/null 2>&1 || true
  done
  if ! guest_network_config_ok "$name" "$ip" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}"; then
    echo "ERROR: Guest network still looks incomplete after guest network setup."
    diagnose_guest_network "$name" "$ip"
    _rollback_vps_full "$name" "$ip" "$port"
    return 1
  fi

  echo "Installing and configuring SSH in $name..."
  _install_ssh "$name" "$ip" "$port" || return 1

  _configure_guest_optimizations "$name"

  if [[ "${open_ssh,,}" =~ ^y ]]; then
    add_forward_rule "$ip" "$port"
    set_vps_user "$name" "root"
    set_vps_password "$name" "$ROOT_PASSWORD"
    set_vps_saved_port "$name" "$port"
    sync_vps_metadata "$name"
    echo "Done: ssh root@$PUBLIC_IP -p $port"
  else
    set_vps_user "$name" "root"
    set_vps_password "$name" "$ROOT_PASSWORD"
    set_vps_saved_port "$name" "$port"
    sync_vps_metadata "$name"
    echo "Done: VPS $name created (SSH external forwarding disabled, accessible via Shell / Internal IP $ip:22)"
  fi
  mark_vps_state "$name" ""
  pending_operation_clear "$name"
}
