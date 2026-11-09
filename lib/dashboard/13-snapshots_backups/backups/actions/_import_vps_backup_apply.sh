#!/bin/bash
# The unpack-and-configure half of import_vps_backup. It uses the variables of
# import_vps_backup (file_path, target_name, rules_to_apply, domains_to_apply,
# caddy_conflicts_to_remove, proxy_decoded). Always call it through run_guarded.
_import_vps_backup_apply() {
  pending_operation_set "$target_name" "" ""
  incus import "$file_path" "$target_name" >/dev/null 2>&1 &
  local import_pid=$!
  local progress=0
  local spinner="-\\|/"
  local spin_idx=0
  
  while kill -0 $import_pid 2>/dev/null; do
    if [ "$progress" -lt 70 ]; then
      printf "\r[ %3d%% ] Extracting backup file...   " "$progress"
      progress=$((progress + 1))
    else
      printf "\r[  70%% ] Extracting backup file... %c " "${spinner:$spin_idx:1}"
      spin_idx=$(( (spin_idx + 1) % 4 ))
    fi
    sleep 0.5
  done
  wait $import_pid
  if [ $? -ne 0 ]; then
    printf "\r[ FAILED ] Extracting backup file...       \n"
    echo "ERROR: incus could not unpack the backup file (corrupt file or not enough disk space)."
    return 1
  fi
  printf "\r[  70%% ] Extracting backup file... Done!    \n"

  mark_vps_state "$target_name" importing

  # The address was decided before the import (see import_vps_backup). The login saved in the backup is kept;
  # the old address and port stored in it are not ours any more.
  local kept_user kept_pw
  kept_user=$(get_vps_user "$target_name"); kept_pw=$(get_vps_password "$target_name")
  incus config unset "$target_name" user.vpsforge.ip >/dev/null 2>&1 || true
  incus config unset "$target_name" user.vpsforge.ssh_port >/dev/null 2>&1 || true

  echo "[  75% ] Applying Incus compatibility & basic network..."
  incus config unset "$target_name" volatile.eth0.hwaddr >/dev/null 2>&1 || true
  incus config unset "$target_name" volatile.eth0.host_name >/dev/null 2>&1 || true
  incus config device unset "$target_name" eth0 hwaddr >/dev/null 2>&1 || true
  apply_incus_compatibility_profile "$target_name" >/dev/null 2>&1 || true
  configure_vps_network_device "$target_name" >/dev/null 2>&1 || true
  incus config set "$target_name" user.vpsforge.ip "$new_ip" >/dev/null 2>&1 || true
  incus config set "$target_name" user.vpsforge.num "$new_num" >/dev/null 2>&1 || true
  incus config set "$target_name" user.vpsforge.ssh_port "$new_port" >/dev/null 2>&1 || true

  echo "[  80% ] Starting container $target_name..."
  incus start "$target_name" 2>/dev/null || true
  wait_ready "$target_name" >/dev/null 2>&1 || true

  incus exec "$target_name" -- rm -f /.dockerenv >/dev/null 2>&1 || true   # backups from old versions may carry the Docker marker
  echo "[  85% ] Waiting for network interface (eth0)..."
  wait_guest_eth0 "$target_name" >/dev/null 2>&1 || true

  echo "[  90% ] Applying static IP ($new_ip) & DNS..."
  apply_guest_static_network "$target_name" "$new_ip" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}" >/dev/null 2>&1 || true
  configure_guest_dns "$target_name" >/dev/null 2>&1 || true
  set_guest_hostname "$target_name"

  # Apply resolved Port Forwarding rules
  echo "[  95% ] Restoring port forwarding rules..."
  add_forward_rule "$new_ip" "$new_port" >/dev/null 2>&1 || true
  set_vps_user "$target_name" "${kept_user:-root}"
  set_vps_password "$target_name" "${kept_pw:-$ROOT_PASSWORD}"
  set_vps_saved_port "$target_name" "$new_port"

  if [ "${#rules_to_apply[@]}" -gt 0 ]; then
    local r proto ext_ip ext_port int_port
    for r in "${rules_to_apply[@]}"; do
      IFS='|' read -r proto ext_ip ext_port int_port <<< "$r"
      port_forward_apply_rule "$proto" "$ext_ip" "$ext_port" "$new_ip" "$int_port"
      echo "${proto}|${ext_ip}|${ext_port}|${new_ip}|${int_port}" >> "$PORT_FORWARD_RULES_FILE"
    done
    save_iptables
  fi

  # Apply resolved Caddy proxy configurations
  echo "[  98% ] Restoring proxy configurations..."
  if [ "${#domains_to_apply[@]}" -gt 0 ]; then
    # Keep a copy of every Caddy file: if the result does not validate, everything goes back.
    local conf_backup entry
    conf_backup=$(mktemp -d)
    mkdir -p "$CADDY_CONF_DIR"
    cp -a "$CADDY_CONF_DIR"/. "$conf_backup"/ 2>/dev/null || true
    local loser
    for entry in "${caddy_conflicts_to_remove[@]}"; do
      caddy_unlink_domain "${entry%%|*}" "${entry#*|}"   # only the taken-over domain leaves the other VPS
      loser=$(basename "${entry%%|*}" .caddy)
      sync_vps_metadata "$loser" || true
      tunnel_reconcile_import "$loser" "$(get_ip "$loser")" "$(get_vps_saved_port "$loser")"
    done
    
    local conf_file="$CADDY_CONF_DIR/${target_name}.caddy" skipped_dom
    mkdir -p "$CADDY_CONF_DIR"
    local joined_domains
    joined_domains=$(local IFS=", "; echo "${domains_to_apply[*]}")

    printf '%s\n' "$proxy_decoded" > "$conf_file"
    for skipped_dom in "${domains_skipped[@]}"; do
      caddy_unlink_domain "$conf_file" "$skipped_dom"
    done
    [ -f "$conf_file" ] && update_vps_proxy_ip "$target_name" "$new_ip"
    
    caddy validate --config "$MAIN_CADDYFILE" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      systemctl reload-or-restart caddy >/dev/null 2>&1 || true
      echo "   SUCCESS: Linked domains ($joined_domains) restored."
    else
      echo "   ERROR: Caddy validation failed. Restoring proxy cancelled; nothing was changed."
      rm -f "$CADDY_CONF_DIR"/*.caddy
      cp -a "$conf_backup"/. "$CADDY_CONF_DIR"/ 2>/dev/null || true
    fi
    rm -rf "$conf_backup"
  fi

  tunnel_reconcile_import "$target_name" "$new_ip" "$new_port" renew   # its tunnels must match what really came back
  sync_vps_metadata "$target_name" || true
  incus config set "$target_name" user.vpsforge.last_restore "$(date '+%Y-%m-%d %H:%M:%S UTC')" 2>/dev/null || true

  mark_vps_state "$target_name" ""
  pending_operation_clear "$target_name"
  echo "[ 100% ] Success: $target_name restored at $new_ip (SSH Port $new_port)"
}
