#!/bin/bash

# Restores a VPS container to a specified snapshot.
restore_vps_snapshot() {
  local name="${1:-}" snap_name="${2:-}" was_running=false
  [ -z "$snap_name" ] && { echo "No snapshot specified."; return 1; }

  snap_name="$(_resolve_snapshot_name "$name" "$snap_name")"

  if is_vps_running "$name"; then
    was_running=true
    echo "Container $name is currently running. Stopping it to restore snapshot..."
    incus stop "$name" --force 2>/dev/null || true
    local wait_count=0
    while is_vps_running "$name" && [ $wait_count -lt 15 ]; do
      sleep 1
      wait_count=$((wait_count + 1))
    done
  fi

  local kept_tunnels cur_ip cur_port
  kept_tunnels=$(incus config get "$name" user.vpsforge.tunnels 2>/dev/null || true)
  cur_ip=$(incus config get "$name" user.vpsforge.ip 2>/dev/null || true)
  cur_port=$(get_vps_saved_port "$name" 2>/dev/null || true)
  RESTORE_FIX_GUEST_IP=""
  echo "Restoring $name to snapshot '$snap_name'..."
  if incus snapshot restore "$name" "$snap_name"; then
    echo "Snapshot '$snap_name' restored successfully."
    _restore_snapshot_keep_address "$name" "$cur_ip" "$cur_port"
    _restore_snapshot_post_config "$name" "$kept_tunnels"
    if [ "$was_running" = true ]; then
      echo "Restarting container $name..."
      incus start "$name" 2>/dev/null || true
    fi
    # the guest's own network file came back from the snapshot too: give it the current address
    if [ -n "$RESTORE_FIX_GUEST_IP" ]; then
      if is_vps_running "$name"; then
        apply_guest_static_network "$name" "$RESTORE_FIX_GUEST_IP" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}" >/dev/null 2>&1 || true
      else
        incus start "$name" >/dev/null 2>&1 || true
        wait_ready "$name" >/dev/null 2>&1 || true
        apply_guest_static_network "$name" "$RESTORE_FIX_GUEST_IP" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}" >/dev/null 2>&1 || true
        incus stop "$name" --force >/dev/null 2>&1 || true
      fi
    fi
  else
    echo "Failed to restore snapshot '$snap_name'."
    if [ "$was_running" = true ]; then
      echo "Restarting container $name..."
      incus start "$name" 2>/dev/null || true
    fi
    return 1
  fi
}
