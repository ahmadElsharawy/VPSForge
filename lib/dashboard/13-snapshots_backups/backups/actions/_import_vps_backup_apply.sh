#!/bin/bash
# The unpack-and-configure half of import_vps_backup. It uses the variables of
# import_vps_backup (file_path, target_name, rules_to_apply, domains_to_apply,
# caddy_conflicts_to_remove, proxy_decoded). Always call it through run_guarded.
_import_vps_backup_apply() {
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

  get_next_available_vps_ip_and_num
  new_num="$NEXT_AVAIL_NUM"
  new_ip="$NEXT_AVAIL_IP"
  new_port=$(vps_fixed_port "$new_num")

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
  set_vps_user "$target_name" "root"
  set_vps_password "$target_name" "$ROOT_PASSWORD"
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
    local conf
    for conf in "${caddy_conflicts_to_remove[@]}"; do
      rm -f "$conf"
    done
    
    local conf_file="$CADDY_CONF_DIR/${target_name}.caddy"
    mkdir -p "$CADDY_CONF_DIR"
    local joined_domains
    joined_domains=$(local IFS=", "; echo "${domains_to_apply[*]}")
    
    local body
    body=$(echo "$proxy_decoded" | sed -n '/{/,$p')
    echo "$joined_domains $body" > "$conf_file"
    
    update_vps_proxy_ip "$target_name" "$new_ip"
    
    caddy validate --config "$MAIN_CADDYFILE" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      systemctl reload-or-restart caddy >/dev/null 2>&1 || true
      echo "   SUCCESS: Linked domains ($joined_domains) restored."
    else
      echo "   ERROR: Caddy validation failed. Restoring proxy cancelled."
      rm -f "$conf_file"
    fi
  fi

  sync_vps_metadata "$target_name" || true
  incus config set "$target_name" user.vpsforge.last_restore "$(date '+%Y-%m-%d %H:%M:%S UTC')" 2>/dev/null || true

  mark_vps_state "$target_name" ""
  echo "[ 100% ] Success: $target_name restored at $new_ip (SSH Port $new_port)"
}
