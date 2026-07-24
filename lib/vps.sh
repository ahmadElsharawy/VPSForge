#!/bin/bash
# VPSForge — VPS lifecycle: create, configure, repair, user/password management.

# ── VPS State Queries ────────────────────────────────────────────────────────

get_state() { incus list "$1" -c s --format csv 2>/dev/null | head -1; }

get_ram() {
  local r
  r=$(incus config get "$1" limits.memory 2>/dev/null || true)
  echo "${r:-Unlimited}"
}

wait_ready() {
  local i
  for i in $(seq 1 60); do
    incus exec "$1" -- true >/dev/null 2>&1 && return 0
    sleep 2
  done
  return 1
}

# ── Dynamic Ubuntu Image Discovery ──────────────────────────────────────────

fetch_available_ubuntu_images() {
  local force="${1:-false}"
  local cache_ttl=86400
  local now file_mtime age

  if [ "$force" = "true" ]; then
    rm -f "$UBUNTU_IMAGES_CACHE_FILE"
  elif [ -f "$UBUNTU_IMAGES_CACHE_FILE" ]; then
    now=$(date +%s 2>/dev/null || echo 0)
    file_mtime=$(stat -c %Y "$UBUNTU_IMAGES_CACHE_FILE" 2>/dev/null || stat -f %m "$UBUNTU_IMAGES_CACHE_FILE" 2>/dev/null || echo 0)
    age=$((now - file_mtime))
    if [ "$age" -lt "$cache_ttl" ] && [ -s "$UBUNTU_IMAGES_CACHE_FILE" ]; then
      return 0
    fi
  fi

  echo "Searching for available Ubuntu releases from Incus repository..." >&2
  local dynamic_images
  dynamic_images=$(incus image list images:ubuntu type=container architecture=amd64 --format csv 2>/dev/null |
    awk -F',' '$1 ~ /^ubuntu\// {
      alias = $1;
      sub(/[[:space:]].*/, "", alias);
      split(alias, a, "/");
      rel = a[2];
      var = a[3];
      if (rel ~ /^[0-9]+(\.[0-9]+)*$/) {
        if (var != "" && var !~ /^(amd64|arm64|i386|s390x|ppc64el|cloud)$/) {
          print "images:ubuntu/" rel "/" var;
        } else {
          print "images:ubuntu/" rel;
        }
      }
    }' | sort -u -V -r 2>/dev/null || true)

  if [ -n "$dynamic_images" ]; then
    mkdir -p "$(dirname "$UBUNTU_IMAGES_CACHE_FILE")"
    echo "$dynamic_images" > "$UBUNTU_IMAGES_CACHE_FILE"
  fi
}

# ── User / Password / Port Metadata ─────────────────────────────────────────

get_vps_user() {
  local u
  u=$(incus config get "$1" user.vpsforge.username 2>/dev/null || true)
  echo "${u:-root}"
}

set_vps_user()      { incus config set "$1" user.vpsforge.username "$2"; }

get_vps_password() {
  local p
  p=$(incus config get "$1" user.vpsforge.password 2>/dev/null || true)
  echo "${p:-$ROOT_PASSWORD}"
}

set_vps_password()  { incus config set "$1" user.vpsforge.password "$2"; }
get_vps_saved_port(){ incus config get "$1" user.vpsforge.ssh_port 2>/dev/null || true; }
set_vps_saved_port(){ incus config set "$1" user.vpsforge.ssh_port "$2"; }

# ── Incus Compatibility Profile ──────────────────────────────────────────────

apply_incus_compatibility_profile() {
  local name="$1" raw_lxc

  incus config set "$name" security.nesting true >/dev/null 2>&1 || true
  incus config set "$name" security.privileged true >/dev/null 2>&1 || true
  incus config set "$name" security.syscalls.intercept.mknod true >/dev/null 2>&1 || true
  incus config set "$name" security.syscalls.intercept.setxattr true >/dev/null 2>&1 || true
  incus config set "$name" linux.kernel_modules \
    "overlay,br_netfilter,nf_nat,ip_tables,iptable_nat,iptable_filter,bridge,veth,fuse,tun" >/dev/null 2>&1 || true

  raw_lxc=$(cat <<'EOF'
lxc.apparmor.profile=unconfined
lxc.cap.drop=
EOF
)
  if ! incus config set "$name" raw.lxc "$raw_lxc" >/dev/null 2>&1; then
    echo "WARNING: Incus rejected the optional raw.lxc compatibility settings for $name; continuing without them." >&2
  fi

  return 0
}

# ── VPS Creation ─────────────────────────────────────────────────────────────

create_vps() {
  local name="$1" num="$2" ram="$3" port="$4"
  local ram_mode="${5:-limited}" cpu_mode="${6:-unlimited}" cpu_value="${7:-}"
  local disk_mode="${8:-unlimited}" disk_value="${9:-}"
  local network_mode="${10:-unlimited}" network_value="${11:-}"
  local image="${12:-$VPS_IMAGE}"
  local ip="${NETWORK_PREFIX}.$((IP_START+num-1))"

  port=$(vps_fixed_port "$num")
  check_fixed_port_available "$name" "$ip" "$port" || return 1

  local ram_label cpu_label
  [ "$ram_mode" = "unlimited" ] && ram_label="Unlimited" || ram_label="${ram}MB"
  [ "$cpu_mode" = "unlimited" ] && cpu_label="$(get_host_cpu_count) Core(s)" || cpu_label="${cpu_value} Core(s)"
  echo "Creating $name | Image: $image | RAM $ram_label | CPU $cpu_label | IP $ip | Port $port"

  incus launch "$image" "$name" || return 1
  incus config set "$name" user.vpsforge.image "$image" || true

  # Apply compatibility profile — rollback on failure.
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

  # Apply resource limits — rollback on failure.
  _apply_resource_limit "$name" ram  "$ram_mode"     "$ram"         || { _rollback_vps "$name"; return 1; }
  _apply_resource_limit "$name" cpu  "$cpu_mode"     "$cpu_value"   || { _rollback_vps "$name"; return 1; }
  _apply_resource_limit "$name" disk "$disk_mode"    "$disk_value"  || { _rollback_vps "$name"; return 1; }
  _apply_resource_limit "$name" net  "$network_mode" "$network_value" || { _rollback_vps "$name"; return 1; }

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

  add_forward_rule "$ip" "$port"
  set_vps_user "$name" "root"
  set_vps_password "$name" "$ROOT_PASSWORD"
  set_vps_saved_port "$name" "$port"

  echo "Done: ssh root@$PUBLIC_IP -p $port"
}

# ── Private: Creation Helpers ────────────────────────────────────────────────

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
    if incus exec "$name" -- bash -c '
      set -e
      export DEBIAN_FRONTEND=noninteractive
      mkdir -p /etc/apt/apt.conf.d
      printf "Acquire::ForceIPv4 \"true\";\n" > /etc/apt/apt.conf.d/99force-ipv4
      apt-get -o Acquire::ForceIPv4=true update
      apt-get -o Acquire::ForceIPv4=true install -y openssh-server
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

  incus exec "$name" -- bash -c '
    set -e
    mkdir -p /etc/ssh/sshd_config.d
    printf "PermitRootLogin yes\nPasswordAuthentication yes\n" > /etc/ssh/sshd_config.d/99-root-login.conf
    systemctl enable --now ssh
  ' || {
    echo "Failed to enable SSH in $name."
    _rollback_vps_full "$name" "$ip" "$port"
    return 1
  }

  local ssh_ready=0 i
  for i in $(seq 1 30); do
    if incus exec "$name" -- bash -c 'ss -lnt 2>/dev/null | grep -qE "[:.]22[[:space:]]"'; then
      ssh_ready=1
      break
    fi
    sleep 1
  done

  [ "$ssh_ready" -eq 1 ] || {
    echo "SSH verification failed in $name."
    _rollback_vps_full "$name" "$ip" "$port"
    return 1
  }

  return 0
}

# ── VPS Editing ──────────────────────────────────────────────────────────────

validate_port() {
  local port="$1" current_ip="${2:-}" existing_ip
  [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ] || return 1
  existing_ip=$(iptables -t nat -L PREROUTING -n 2>/dev/null | awk -v p="$port" '
    $0 ~ "dpt:" p "([^0-9]|$)" {
      if (match($0,/to:([0-9.]+):22/,m)) print m[1]
      exit
    }' 2>/dev/null || true)
  [ -z "$existing_ip" ] || [ "$existing_ip" = "$current_ip" ]
}

change_vps_username() {
  local name="$1" new_user="$2" old_user password
  old_user=$(get_vps_user "$name")
  password=$(get_vps_password "$name")

  [[ "$new_user" =~ ^[a-z_][a-z0-9_-]*$ ]] || { echo "Invalid username: $new_user"; return 1; }

  incus exec "$name" -- bash -c "id '$new_user' >/dev/null 2>&1 || useradd -m -s /bin/bash '$new_user'"
  incus exec "$name" -- usermod -aG sudo "$new_user" 2>/dev/null || true
  printf '%s:%s\n' "$new_user" "$password" | incus exec "$name" -- chpasswd
  set_vps_user "$name" "$new_user"

  echo "Username changed for $name: $old_user -> $new_user"
}

change_vps_password() {
  local name="$1" password="$2" user
  user=$(get_vps_user "$name")
  printf '%s:%s\n' "$user" "$password" | incus exec "$name" -- chpasswd || return 1
  set_vps_password "$name" "$password"
  echo "Password changed for $name."
}

change_vps_port() {
  local name="$1" new_port="$2" ip old_port
  ip=$(get_ip "$name")
  old_port=$(get_port "$ip")
  validate_port "$new_port" "$ip" || { echo "Port $new_port is invalid or already in use."; return 1; }

  [ -n "$old_port" ] && remove_port "$old_port"
  add_forward_rule "$ip" "$new_port"
  set_vps_saved_port "$name" "$new_port"
  echo "SSH port changed for $name: ${old_port:--} -> $new_port"
}

# ── VPS Connection Repair ───────────────────────────────────────────────────

repair_vps_connection() {
  local name="$1" ip port reachable=0

  [ "$(get_state "$name")" = "RUNNING" ] || incus start "$name"
  wait_ready "$name" || { echo "FAILED: $name did not become ready."; return 1; }

  apply_incus_compatibility_profile "$name" || echo "WARNING: could not refresh compatibility profile for $name."
  incus restart "$name" || true
  wait_ready "$name" || { echo "FAILED: $name did not become ready after profile refresh."; return 1; }
  incus exec "$name" -- touch /.dockerenv 2>/dev/null || true

  ip=$(get_ip "$name")
  [ -n "$ip" ] || { echo "FAILED: No IPv4 for $name."; return 1; }

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

# ── Preserve VPS Settings (for Reinstall) ────────────────────────────────────
# Reads current resource limits and credentials into PRESERVED_* globals.
# Used by reinstall_vps_menu() to avoid duplicating this extraction logic.

preserve_vps_settings() {
  local name="$1"

  PRESERVED_RAM_LIMIT=$(get_vps_ram_limit_mb "$name")
  PRESERVED_CPU_LIMIT=$(incus config get "$name" limits.cpu 2>/dev/null || true)
  PRESERVED_DISK_LIMIT=$(get_vps_disk_limit_gb "$name")
  PRESERVED_NETWORK_LIMIT=$(get_vps_network_limit_mbit "$name")

  if [ -n "$PRESERVED_RAM_LIMIT" ]; then
    PRESERVED_RAM_MODE="limited"
  else
    PRESERVED_RAM_MODE="unlimited"
    PRESERVED_RAM_LIMIT="$MIN_RAM_MB"
  fi

  PRESERVED_CPU_MODE="unlimited"
  [ -n "$PRESERVED_CPU_LIMIT" ] && PRESERVED_CPU_MODE="limited"

  PRESERVED_DISK_MODE="unlimited"
  [ -n "$PRESERVED_DISK_LIMIT" ] && PRESERVED_DISK_MODE="limited"

  PRESERVED_NETWORK_MODE="unlimited"
  [ -n "$PRESERVED_NETWORK_LIMIT" ] && PRESERVED_NETWORK_MODE="limited"

  PRESERVED_USER=$(get_vps_user "$name")
  PRESERVED_PASSWORD=$(get_vps_password "$name")
}

print_preserved_settings() {
  local name="$1" port="$2"
  echo "Preserving $name settings:"
  echo "  RAM: $PRESERVED_RAM_MODE ${PRESERVED_RAM_LIMIT:+${PRESERVED_RAM_LIMIT}MB}"
  echo "  CPU: $PRESERVED_CPU_MODE ${PRESERVED_CPU_LIMIT:+${PRESERVED_CPU_LIMIT} core(s)}"
  echo "  Disk: $PRESERVED_DISK_MODE ${PRESERVED_DISK_LIMIT:+${PRESERVED_DISK_LIMIT}GB}"
  echo "  Network: $PRESERVED_NETWORK_MODE ${PRESERVED_NETWORK_LIMIT:+${PRESERVED_NETWORK_LIMIT}Mbit}"
  echo "  Port: $port"
}

# ── Snapshots & Backups ──────────────────────────────────────────────────────

create_vps_snapshot() {
  local name="$1" snap_name="$2"
  [ -z "$snap_name" ] && snap_name="snap-$(date +%Y%m%d-%H%M%S)"
  sync_vps_metadata "$name"
  echo "Creating snapshot '$snap_name' for $name..."
  incus snapshot create "$name" "$snap_name" && echo "Snapshot '$snap_name' created successfully."
}

list_vps_snapshots() {
  local name="$1"
  echo "Snapshots for $name:"
  incus snapshot list "$name" --format csv 2>/dev/null | awk -F',' 'NF {printf "  - %s (Created: %s)\n", $1, $2}' || echo "No snapshots found."
}

restore_vps_snapshot() {
  local name="$1" snap_name="$2"
  echo "Restoring $name to snapshot '$snap_name'..."
  if incus snapshot restore "$name" "$snap_name"; then
    echo "Snapshot '$snap_name' restored successfully."
    restore_vps_port_forwards_metadata "$name"
  fi
}

delete_vps_snapshot() {
  local name="$1" snap_name="$2"
  echo "Deleting snapshot '$snap_name' from $name..."
  incus snapshot delete "$name" "$snap_name" && echo "Snapshot '$snap_name' deleted."
}

BACKUP_FILES_RESULT=()
SELECTED_BACKUP_FILE=""

list_backup_files() {
  local f size mtime idx=1
  mkdir -p "$BACKUP_DIR"
  BACKUP_FILES_RESULT=()

  while IFS= read -r f; do
    [ -f "$f" ] || continue
    BACKUP_FILES_RESULT+=("$f")
  done < <(find "$BACKUP_DIR" -maxdepth 1 -type f -name "*.tar.gz" 2>/dev/null | sort -r || true)

  if [ "${#BACKUP_FILES_RESULT[@]}" -eq 0 ]; then
    echo "No backup files found in $BACKUP_DIR."
    return 1
  fi

  echo "Available Backup Files in $BACKUP_DIR:"
  for i in "${!BACKUP_FILES_RESULT[@]}"; do
    f="${BACKUP_FILES_RESULT[$i]}"
    size=$(du -h "$f" 2>/dev/null | awk '{print $1}')
    mtime=$(stat -c "%y" "$f" 2>/dev/null | cut -d'.' -f1 || echo "-")
    printf "  %2d) %-40s (%s | %s)\n" "$((i+1))" "$(basename "$f")" "$size" "$mtime"
  done
  return 0
}

select_backup_file() {
  local prompt="${1:-Choice: }" c custom_path
  SELECTED_BACKUP_FILE=""

  if list_backup_files; then
    echo "   C) Enter custom file path"
    read -r -p "$prompt" c
    if [[ "${c,,}" = "c" ]]; then
      read -r -p "Path to custom backup file (.tar.gz): " custom_path
      if [ -f "$custom_path" ]; then
        SELECTED_BACKUP_FILE="$custom_path"
        return 0
      else
        echo "File not found: $custom_path"
        return 1
      fi
    elif [[ "$c" =~ ^[0-9]+$ ]] && [ "$c" -ge 1 ] && [ "$c" -le "${#BACKUP_FILES_RESULT[@]}" ]; then
      SELECTED_BACKUP_FILE="${BACKUP_FILES_RESULT[$((c-1))]}"
      return 0
    else
      echo "Invalid selection."
      return 1
    fi
  else
    read -r -p "Path to custom backup file (.tar.gz): " custom_path
    if [ -f "$custom_path" ]; then
      SELECTED_BACKUP_FILE="$custom_path"
      return 0
    else
      [ -n "$custom_path" ] && echo "File not found: $custom_path"
      return 1
    fi
  fi
}

delete_backup_file() {
  local confirm
  if select_backup_file "Select backup file to DELETE: "; then
    inspect_backup_file "$SELECTED_BACKUP_FILE"
    read -r -p "Are you sure you want to delete '$(basename "$SELECTED_BACKUP_FILE")'? [y/N]: " confirm
    if [[ "${confirm,,}" =~ ^y ]]; then
      rm -f "$SELECTED_BACKUP_FILE" && echo "Backup file '$(basename "$SELECTED_BACKUP_FILE")' deleted."
      rm -f "${SELECTED_BACKUP_FILE}.info" 2>/dev/null || true
    else
      echo "Deletion cancelled."
    fi
  fi
}

inspect_backup_file() {
  local file_path="${1:-${SELECTED_BACKUP_FILE:-}}" index_content
  [ -n "$file_path" ] && [ -f "$file_path" ] || { echo "File not found: $file_path"; return 1; }

  local size mtime orig_name orig_ip orig_port ram_lim cpu_lim os_img pfs
  size=$(du -h "$file_path" 2>/dev/null | awk '{print $1}')
  mtime=$(stat -c "%y" "$file_path" 2>/dev/null | cut -d'.' -f1 || echo "-")

  local info_path="${file_path}.info"
  if [ -f "$info_path" ]; then
    index_content=$(cat "$info_path" 2>/dev/null || true)
  else
    echo ""
    local tar_pid progress=0 tmp_meta="/tmp/vpsforge_meta_$$.yaml"
    ( tar -zxvf "$file_path" backup/index.yaml -O > "$tmp_meta" ) >/dev/null 2>&1 &
    tar_pid=$!
    
    while kill -0 $tar_pid 2>/dev/null; do
      printf "\r[ %3d%% ] Inspecting backup metadata..." "$progress"
      sleep 1
      if [ "$progress" -lt 99 ]; then
        progress=$((progress + 1))
      fi
    done
    wait $tar_pid
    printf "\r[ 100%% ] Inspecting backup metadata... Done!\n\n"
    
    index_content=$(cat "$tmp_meta" 2>/dev/null || true)
    rm -f "$tmp_meta" 2>/dev/null
    
    # Cache it for next time
    echo "$index_content" > "$info_path" 2>/dev/null || true
  fi

  orig_name=$(basename "$file_path" | cut -d'-' -f1)
  orig_ip=$(echo "$index_content" | awk -F': ' '/user\.vpsforge\.ip:/{print $2; exit}' | tr -d '"' | tr -d "'" || echo "-")
  orig_port=$(echo "$index_content" | awk -F': ' '/user\.vpsforge\.ssh_port:/{print $2; exit}' | tr -d '"' | tr -d "'" || echo "-")
  ram_lim=$(echo "$index_content" | awk -F': ' '/limits\.memory:/{print $2; exit}' | tr -d '"' | tr -d "'" || echo "Unlimited")
  cpu_lim=$(echo "$index_content" | awk -F': ' '/limits\.cpu:/{print $2; exit}' | tr -d '"' | tr -d "'" || echo "Unlimited")
  os_img=$(echo "$index_content" | awk -F': ' '/user\.vpsforge\.image:/{print $2; exit}' | tr -d '"' | tr -d "'" || echo "Ubuntu")
  pfs=$(echo "$index_content" | awk -F': ' '/user\.vpsforge\.portforwards:/{print $2; exit}' | tr -d '"' | tr -d "'" || echo "-")

  [ -n "$orig_ip" ] || orig_ip="-"
  [ -n "$orig_port" ] || orig_port="-"
  [ -n "$ram_lim" ] || ram_lim="Unlimited"
  [ -n "$cpu_lim" ] || cpu_lim="Unlimited"
  [ -n "$os_img" ] || os_img="Ubuntu"

  echo "================================================"
  echo "            BACKUP FILE DETAILS"
  echo "================================================"
  echo "File:            $(basename "$file_path")"
  echo "File Size:       $size"
  echo "Creation Time:   $mtime"
  echo "Original VPS:    $orig_name"
  echo "Original IP:     $orig_ip"
  echo "SSH Port:        $orig_port"
  echo "RAM Limit:       $ram_lim"
  echo "CPU Limit:       $cpu_lim"
  echo "OS Image:        $os_img"
  if [ -n "$pfs" ] && [ "$pfs" != "-" ]; then
    echo "Forwarded Ports: $(echo "$pfs" | tr ';' ' ')"
  else
    echo "Forwarded Ports: None"
  fi
  echo "================================================"
}

update_vps_backup() {
  local name confirm
  ask_vps_selection "Select VPS container to update backup for: " || return
  [ "${#SELECTED_VPS[@]}" -eq 1 ] || { echo "Supports one VPS at a time."; return; }
  name="${SELECTED_VPS[0]}"

  if select_backup_file "Select backup file to OVERWRITE / UPDATE: "; then
    inspect_backup_file "$SELECTED_BACKUP_FILE"
    read -r -p "Overwrite and update '$(basename "$SELECTED_BACKUP_FILE")' with fresh data from $name? [y/N]: " confirm
    if [[ "${confirm,,}" =~ ^y ]]; then
      sync_vps_metadata "$name"
      echo "Exporting fresh backup for $name to $SELECTED_BACKUP_FILE..."
      if incus export "$name" "$SELECTED_BACKUP_FILE" --overwrite; then
        echo "Backup updated successfully: $SELECTED_BACKUP_FILE"
        incus config show "$name" --expanded > "${SELECTED_BACKUP_FILE}.info" 2>/dev/null || true
      fi
    else
      echo "Update cancelled."
    fi
  fi
}

export_vps_backup() {
  local name="$1" file_path
  sync_vps_metadata "$name"
  mkdir -p "$BACKUP_DIR"
  file_path="${BACKUP_DIR}/${name}-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
  echo "Exporting backup for $name to $file_path..."
  if incus export "$name" "$file_path"; then
    echo "Backup saved: $file_path"
    incus config show "$name" --expanded > "${file_path}.info" 2>/dev/null || true
  fi
}

import_vps_backup() {
  local file_path="$1" name="${2:-}" target_name c new_num new_ip new_port
  [ -f "$file_path" ] || { echo "File not found: $file_path"; return 1; }

  inspect_backup_file "$file_path"

  if [ -z "$name" ]; then
    target_name=$(basename "$file_path" | cut -d'-' -f1)
  else
    target_name="$name"
  fi

  if incus list -c n --format csv 2>/dev/null | grep -Fxq "$target_name"; then
    echo "WARNING: Instance '$target_name' currently exists on this server."
    echo "1) Import under a different name"
    echo "2) Overwrite / Replace current '$target_name' with backup"
    echo "0) Cancel"
    read -r -p "Choice: " c
    case "$c" in
      1)
        local auto_next
        auto_next="${VPS_PREFIX}$(next_num)"
        read -r -p "Enter new VPS name [default: $auto_next]: " target_name
        [ -z "$target_name" ] && target_name="$auto_next"
        ;;
      2)
        echo "Deleting current $target_name..."
        local old_ip old_port
        old_ip=$(get_ip "$target_name"); old_port=$(get_port "$old_ip")
        remove_ip "$old_ip"; [ -n "$old_port" ] && remove_port "$old_port"
        [ -n "$old_ip" ] && port_forward_delete_rules_for_ip "$old_ip"
        rm -f "/etc/caddy/vpsforge/${target_name}.caddy"
        incus delete "$target_name" --force >/dev/null 2>&1 || true
        ;;
      *)
        echo "Import cancelled."
        return 0
        ;;
    esac
  fi

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
    echo "Import failed."
    return 1
  fi
  printf "\r[  70%% ] Extracting backup file... Done!    \n"

  new_num=$(get_num "$target_name")
  [[ "$new_num" =~ ^[0-9]+$ ]] || new_num=$(next_num)
  new_ip="${NETWORK_PREFIX}.$((IP_START+new_num-1))"
  new_port=$(vps_fixed_port "$new_num")

  echo "[  75% ] Applying Incus compatibility & basic network..."
  apply_incus_compatibility_profile "$target_name" >/dev/null 2>&1 || true
  configure_vps_network_device "$target_name" >/dev/null 2>&1 || true
  incus config set "$target_name" user.vpsforge.ip "$new_ip" >/dev/null 2>&1 || true

  echo "[  80% ] Starting container $target_name..."
  incus start "$target_name" 2>/dev/null || true
  wait_ready "$target_name" >/dev/null 2>&1 || true

  echo "[  85% ] Waiting for network interface (eth0)..."
  wait_guest_eth0 "$target_name" >/dev/null 2>&1 || true

  echo "[  90% ] Applying static IP ($new_ip) & DNS..."
  apply_guest_static_network "$target_name" "$new_ip" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}" >/dev/null 2>&1 || true
  configure_guest_dns "$target_name" >/dev/null 2>&1 || true

  echo "[  95% ] Restoring port forwarding rules..."
  add_forward_rule "$new_ip" "$new_port" >/dev/null 2>&1 || true
  set_vps_user "$target_name" "root"
  set_vps_password "$target_name" "$ROOT_PASSWORD"
  set_vps_saved_port "$target_name" "$new_port"
  restore_vps_port_forwards_metadata "$target_name" "$new_ip" >/dev/null 2>&1 || true

  echo "[  98% ] Restoring proxy configurations..."
  local proxy_b64
  proxy_b64=$(incus config get "$target_name" user.vpsforge.proxy 2>/dev/null || true)
  if [ -n "$proxy_b64" ]; then
    local proxy_file="/etc/caddy/vpsforge/${target_name}.caddy"
    mkdir -p /etc/caddy/vpsforge
    echo "$proxy_b64" | base64 -d > "$proxy_file"
    # Update the internal IP in the Caddyfile to the newly assigned IP
    sed -i -E "s/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/$new_ip/g" "$proxy_file"
    systemctl reload caddy >/dev/null 2>&1 || true
    echo "         Proxy domain routes restored for $target_name!"
  fi

  echo "[ 100% ] Success: $target_name restored at $new_ip (SSH Port $new_port)"
}
