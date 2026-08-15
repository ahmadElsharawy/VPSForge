#!/bin/bash
# VPSForge v1.0.0 — VPS creation, rollback, and SSH installation.

create_vps() {
  local name="$1" num="$2" ram="$3" port="$4"
  local ram_mode="${5:-limited}" cpu_mode="${6:-unlimited}" cpu_value="${7:-}"
  local disk_mode="${8:-unlimited}" disk_value="${9:-}"
  local network_mode="${10:-unlimited}" network_value="${11:-}"
  local image="${12:-$VPS_IMAGE}"
  local traffic_mode="${13:-unlimited}" traffic_rx="${14:-0}" traffic_tx="${15:-0}"
  local ip="${NETWORK_PREFIX}.$((IP_START+num-1))"

  image=$(normalize_image_alias "$image")
  port=$(vps_fixed_port "$num")
  check_fixed_port_available "$name" "$ip" "$port" || return 1

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
    if incus launch "$cand" "$name" 2>/dev/null; then
      launch_ok=1
      launched_image="$cand"
      break
    fi
  done

  if [ "$launch_ok" -eq 0 ]; then
    echo "Attempting fallback with detailed output..."
    for cand in "${candidates[@]}"; do
      [ -n "$cand" ] || continue
      if incus launch "$cand" "$name"; then
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

  incus config set "$name" user.vpsforge.image "$launched_image" || true

  apply_incus_compatibility_profile "$name" || {
    echo "ERROR: Failed to apply Incus compatibility profile for $name."
    incus delete "$name" --force >/dev/null 2>&1 || true
    return 1
  }

  configure_vps_network_device "$name" || {
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

  incus restart "$name" || {
    echo "ERROR: Failed to restart $name."
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

  if ! guest_network_config_ok "$name" "$ip" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}"; then
    echo "ERROR: Guest network still looks incomplete after guest network setup."
    diagnose_guest_network "$name" "$ip"
    _rollback_vps_full "$name" "$ip" "$port"
    return 1
  fi

  echo "Installing and configuring SSH in $name..."
  _install_ssh "$name" "$ip" "$port" || return 1

  _configure_guest_optimizations "$name"

  add_forward_rule "$ip" "$port"
  set_vps_user "$name" "root"
  set_vps_password "$name" "$ROOT_PASSWORD"
  set_vps_saved_port "$name" "$port"

  echo "Done: ssh root@$PUBLIC_IP -p $port"
}

_rollback_vps() {
  local name="$1"
  echo "Deleting incomplete VPS..."
  incus delete "$name" --force >/dev/null 2>&1 || true
}

_rollback_vps_full() {
  local name="$1" ip="$2" port="$3"
  echo "Deleting incomplete VPS..."
  remove_ip "$ip"
  remove_port "$port"
  [ -n "$ip" ] && port_forward_delete_rules_for_ip "$ip"
  incus delete "$name" --force >/dev/null 2>&1 || true
}

_apply_resource_limit() {
  local name="$1" resource="$2" mode="$3" value="$4"
  case "$resource" in
    ram)  set_ram_mode_for_vps "$name" "$mode" "$value";;
    cpu)  set_cpu_mode_for_vps "$name" "$mode" "$value";;
    disk) set_disk_mode_for_vps "$name" "$mode" "$value";;
    net)  set_network_mode_for_vps "$name" "$mode" "$value";;
  esac
}

_install_ssh() {
  local name="$1" ip="$2" port="$3"
  local ssh_install_ok=0 attempt

  for attempt in 1 2 3; do
    if incus exec "$name" -- sh -c '
      set -e
      if command -v apt-get >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        mkdir -p /etc/apt/apt.conf.d
        printf "Acquire::ForceIPv4 \"true\";\n" > /etc/apt/apt.conf.d/99force-ipv4
        apt-get -o Acquire::ForceIPv4=true update
        apt-get -o Acquire::ForceIPv4=true install -y openssh-server
      elif command -v apk >/dev/null 2>&1; then
        apk update
        apk add --no-cache openssh-server openssh
      elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm openssh
      elif command -v dnf >/dev/null 2>&1; then
        dnf install -y openssh-server
      elif command -v yum >/dev/null 2>&1; then
        yum install -y openssh-server
      else
        echo "Unknown package manager."
      fi
    '; then
      ssh_install_ok=1
      break
    fi
    echo "SSH installation attempt $attempt/3 failed for $name. Retrying..."
    sleep 3
  done

  [ "$ssh_install_ok" -eq 1 ] || {
    echo "Failed to install openssh-server in $name after 3 attempts."
    _rollback_vps_full "$name" "$ip" "$port"
    return 1
  }

  printf 'root:%s\n' "$ROOT_PASSWORD" | incus exec "$name" -- chpasswd

  incus exec "$name" -- sh -c '
    set -e
    if [ -d /etc/ssh/sshd_config.d ]; then
      mkdir -p /etc/ssh/sshd_config.d
      printf "PermitRootLogin yes\nPasswordAuthentication yes\n" > /etc/ssh/sshd_config.d/99-root-login.conf
    else
      mkdir -p /etc/ssh
      touch /etc/ssh/sshd_config
      grep -v -E "^(PermitRootLogin|PasswordAuthentication)" /etc/ssh/sshd_config > /etc/ssh/sshd_config.tmp || true
      mv /etc/ssh/sshd_config.tmp /etc/ssh/sshd_config
      printf "PermitRootLogin yes\nPasswordAuthentication yes\n" >> /etc/ssh/sshd_config
    fi

    if command -v systemctl >/dev/null 2>&1; then
      systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null || true
      systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
    elif command -v rc-update >/dev/null 2>&1; then
      rc-update add sshd default 2>/dev/null || true
      /etc/init.d/sshd restart 2>/dev/null || true
    fi
  ' || {
    echo "Failed to enable SSH in $name."
    _rollback_vps_full "$name" "$ip" "$port"
    return 1
  }
}

_configure_guest_optimizations() {
  local name="$1"
  incus exec "$name" -- sh -c '
    # Ensure no legacy or spurious Docker marker exists in native Incus/LXC system container
    rm -f /.dockerenv 2>/dev/null || true
    # Ensure locale is set to avoid warnings if possible
    if command -v locale-gen >/dev/null 2>&1; then
      locale-gen en_US.UTF-8 >/dev/null 2>&1 || true
    fi
    if command -v update-locale >/dev/null 2>&1; then
      update-locale LANG=en_US.UTF-8 >/dev/null 2>&1 || true
    fi
  ' 2>/dev/null || true
}
