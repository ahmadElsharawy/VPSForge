#!/bin/bash
# VPSForge — Interactive menus, dashboard, and display functions.

# ── Dashboard ────────────────────────────────────────────────────────────────

list_vps() {
  printf "%-10s %-10s %-18s %-10s %-16s %-20s %-16s %-8s\n" NAME STATUS RAM CPU DISK NETWORK_IO INTERNAL_IP PORT
  printf '%s\n' "----------------------------------------------------------------------------------------------------------------"

  local n s ram cpu disk net ip p
  local -a vps_list=()

  mapfile -t vps_list < <(
    incus list -c n --format csv 2>/dev/null |
    grep -E "^${VPS_PREFIX}[0-9]+$" |
    sort -V || true
  )

  for n in "${vps_list[@]}"; do
    [ -z "$n" ] && continue

    s=$(get_state "$n" 2>/dev/null || true);       [ -n "$s" ]   || s="-"
    ram=$(format_ram_display "$n" 2>/dev/null || true);  [ -n "$ram" ] || ram="-"

    cpu=$(get_vps_cpu_limit "$n" 2>/dev/null || true)
    if [ -n "$cpu" ]; then
      cpu="${cpu} Core$([ "$cpu" = "1" ] || echo s)"
    else
      cpu="-"
    fi

    disk=$(format_disk_display "$n" 2>/dev/null || true); [ -n "$disk" ] || disk="-"
    net=$(format_network_display "$n" 2>/dev/null || true); [ -n "$net" ] || net="-"

    ip=$(get_ip "$n" 2>/dev/null || true);   [ -n "$ip" ] || ip="-"

    if [ "$ip" != "-" ]; then
      p=$(get_port "$ip" 2>/dev/null || true)
    else
      p=""
    fi
    [ -n "$p" ] || p="-"

    printf "%-10s %-10s %-18s %-10s %-16s %-20s %-16s %-8s\n" \
      "$n" "$s" "$ram" "$cpu" "$disk" "$net" "$ip" "$p"
  done
}

dashboard() {
  clear
  local total allocated rem
  total=$(awk '/MemTotal/{printf "%d",$2/1024}' /proc/meminfo)
  allocated=$(total_allocated)
  rem=$((total-allocated))

  echo "================================================================"
  echo "                    VPSForge MANAGER $VPSFORGE_VERSION"
  echo "================================================================"
  echo "Auto Refresh: $([ "$AUTO_REFRESH" = "on" ] && echo "ON (${REFRESH_INTERVAL}s)" || echo "OFF")"
  echo "Public IP: $PUBLIC_IP | Total RAM: ${total}MB | VPS limits: ${allocated}MB | Remaining: ${rem}MB"
  echo
  list_vps
  echo
  echo "1) Add"
  echo "2) Delete"
  echo "3) Start"
  echo "4) Stop"
  echo "5) Restart"
  echo "6) Reinstall"
  echo "7) Edit VPS"
  echo "8) Details"
  echo "9) Shell"
  echo "10) Connection"
  echo "11) Port Forward"
  echo "12) Domains & Reverse Proxy"
  echo "13) Snapshots & Backups"
  echo "14) Settings"
  echo "15) Exit"
}

# ── Details ──────────────────────────────────────────────────────────────────

details() {
  local name="$1"
  local status ram cpu disk network ip port username
  local ram_limit cpu_limit disk_limit network_limit

  incus info "$name" >/dev/null 2>&1 || { echo "ERROR: VPS '$name' does not exist."; return 1; }

  status=$(get_state "$name" 2>/dev/null || true);   [ -n "$status" ] || status="-"
  ram=$(format_ram_display "$name" 2>/dev/null || true); [ -n "$ram" ] || ram="-"

  cpu=$(get_vps_cpu_limit "$name" 2>/dev/null || true)
  if [ -n "$cpu" ]; then
    cpu="${cpu} Core$([ "$cpu" = "1" ] || echo s)"
  else
    cpu="-"
  fi

  disk=$(format_disk_display "$name" 2>/dev/null || true); [ -n "$disk" ] || disk="-"

  network=$(get_vps_network_limit_mbit "$name" 2>/dev/null || true)
  if [ -n "$network" ]; then
    network="${network}Mbit"
  else
    network=$(get_total_network_mbit 2>/dev/null || true)
    [ -n "$network" ] && network="${network}Mbit" || network="-"
  fi

  ip=$(get_ip "$name" 2>/dev/null || true);   [ -n "$ip" ] || ip="-"

  if [ "$ip" != "-" ]; then
    port=$(get_port "$ip" 2>/dev/null || true)
  else
    port=""
  fi
  [ -n "$port" ] || port=$(get_vps_saved_port "$name" 2>/dev/null || true)
  [ -n "$port" ] || port="-"

  username=$(get_vps_user "$name" 2>/dev/null || true); [ -n "$username" ] || username="-"

  ram_limit=$(get_vps_ram_limit_mb "$name" 2>/dev/null || true)
  cpu_limit=$(incus config get "$name" limits.cpu 2>/dev/null || true)
  disk_limit=$(get_vps_disk_limit_gb "$name" 2>/dev/null || true)
  network_limit=$(get_vps_network_limit_mbit "$name" 2>/dev/null || true)

  echo "================================================"
  echo "                    VPS DETAILS"
  echo "================================================"
  echo "Name:          $name"
  echo "Status:        $status"
  echo "RAM:           $ram"
  echo "RAM Mode:      $([ -n "$ram_limit" ] && echo "Limited (${ram_limit}MB)" || echo "Unlimited")"
  echo "CPU:           $cpu"
  echo "CPU Mode:      $([ -n "$cpu_limit" ] && echo "Limited (${cpu_limit} core(s))" || echo "Unlimited")"
  echo "Disk:          $disk"
  echo "Disk Mode:     $([ -n "$disk_limit" ] && echo "Limited (${disk_limit}GB)" || echo "Unlimited")"
  echo "Network:       $network"
  echo "Network Mode:  $([ -n "$network_limit" ] && echo "Limited (${network_limit}Mbit)" || echo "Unlimited")"
  echo "Internal IP:   $ip"
  echo "SSH Port:      $port"
  echo "Username:      $username"
  if [ "$port" != "-" ]; then
    echo "SSH Command:   ssh ${username}@${PUBLIC_IP} -p ${port}"
  fi
  echo "================================================"
}

# ── Add Menu ─────────────────────────────────────────────────────────────────

select_distro_sub_menu() {
  local distro_name="$1" target="$2" c idx=1
  local -a img_list
  shift 2
  img_list=("$@")

  echo; echo "Select $distro_name Version for $target:"
  for i in "${!img_list[@]}"; do
    printf "  %2d) %s\n" "$((i+1))" "${img_list[$i]}"
  done
  read -r -p "Choice [1-${#img_list[@]}, Enter=1]: " c
  if [[ "$c" =~ ^[0-9]+$ ]] && [ "$c" -ge 1 ] && [ "$c" -le "${#img_list[@]}" ]; then
    UBUNTU_IMAGE_RESULT="${img_list[$((c-1))]}"
  else
    UBUNTU_IMAGE_RESULT="${img_list[0]}"
  fi
}

search_distro_menu() {
  local target="$1" query results_raw c i
  local -a search_results
  read -r -p "Enter distribution search query (e.g. alpine, debian, arch, fedora, rocky, centos, opensuse): " query
  [ -n "$query" ] || query="debian"

  echo "Searching Incus image repository for '$query'..."
  results_raw=$(incus image list "images:${query}" type=container --format csv 2>/dev/null |
    awk -F',' '$1 != "" {
      alias = $1;
      sub(/[[:space:]].*/, "", alias);
      print "images:" alias;
    }' | sort -u -V | head -n 25 || true)

  if [ -z "$results_raw" ]; then
    echo "No images found matching '$query'. Falling back to default Ubuntu."
    UBUNTU_IMAGE_RESULT="$VPS_IMAGE"
    return
  fi

  while IFS= read -r img; do
    [ -n "$img" ] || continue
    search_results+=("$img")
  done <<< "$results_raw"

  echo; echo "Search results for '$query':"
  for i in "${!search_results[@]}"; do
    printf "  %2d) %s\n" "$((i+1))" "${search_results[$i]}"
  done
  read -r -p "Choice [1-${#search_results[@]}, Enter=1]: " c
  if [[ "$c" =~ ^[0-9]+$ ]] && [ "$c" -ge 1 ] && [ "$c" -le "${#search_results[@]}" ]; then
    UBUNTU_IMAGE_RESULT="${search_results[$((c-1))]}"
  else
    UBUNTU_IMAGE_RESULT="${search_results[0]}"
  fi
}

ask_ubuntu_version() {
  local target="$1" c i img
  local -a base_images=(
    "images:ubuntu/24.04"
    "images:ubuntu/22.04"
    "images:ubuntu/20.04"
    "images:ubuntu/24.04/minimal"
    "images:ubuntu/22.04/minimal"
  )
  local -a available_images=("${base_images[@]}")

  fetch_available_ubuntu_images "false"

  if [ -f "$UBUNTU_IMAGES_CACHE_FILE" ] && [ -s "$UBUNTU_IMAGES_CACHE_FILE" ]; then
    while IFS= read -r img; do
      [ -n "$img" ] || continue
      [[ " ${available_images[*]} " == *" $img "* ]] || available_images+=("$img")
    done < "$UBUNTU_IMAGES_CACHE_FILE"
  fi

  echo "Select OS Image for $target:"
  echo "--- Category 1: Ubuntu Releases ---"
  for i in "${!available_images[@]}"; do
    local label="${available_images[$i]}"
    case "$label" in
      "images:ubuntu/24.04")         label="Ubuntu 24.04 LTS (Noble Numbat - Default)";;
      "images:ubuntu/22.04")         label="Ubuntu 22.04 LTS (Jammy Jellyfish)";;
      "images:ubuntu/20.04")         label="Ubuntu 20.04 LTS (Focal Fossa)";;
      "images:ubuntu/24.04/minimal") label="Ubuntu 24.04 Minimal";;
      "images:ubuntu/22.04/minimal") label="Ubuntu 22.04 Minimal";;
    esac

    printf "  %2d) %s\n" "$((i+1))" "$label"
  done

  echo
  echo "--- Category 2: Other Linux Distributions ---"
  echo "   D) Debian (12 Bookworm / 11 Bullseye / 10 Buster)"
  echo "   A) Alpine Linux (3.20 / 3.19)"
  echo "   L) AlmaLinux (9 / 8)"
  echo "   K) Rocky Linux (9 / 8)"
  echo "   C) Arch Linux"
  echo "   F) Fedora / CentOS Stream"
  echo "   S) Search ALL Linux Distributions (Alpine, Debian, Fedora, Arch, etc.)"
  echo "   R) Refresh Image Cache from Incus Repository"

  read -r -p "Choice [1-${#available_images[@]}, D/A/L/K/C/F/S/R, Enter=1]: " c

  case "${c,,}" in
    r)
      fetch_available_ubuntu_images "true"
      ask_ubuntu_version "$target"
      return
      ;;
    d)
      select_distro_sub_menu "Debian" "$target" "images:debian/12" "images:debian/11" "images:debian/10"
      return
      ;;
    a)
      select_distro_sub_menu "Alpine Linux" "$target" "images:alpine/3.20" "images:alpine/3.19" "images:alpine/3.18"
      return
      ;;
    l)
      select_distro_sub_menu "AlmaLinux" "$target" "images:almalinux/9" "images:almalinux/8"
      return
      ;;
    k)
      select_distro_sub_menu "Rocky Linux" "$target" "images:rockylinux/9" "images:rockylinux/8"
      return
      ;;
    c)
      UBUNTU_IMAGE_RESULT="images:archlinux"
      return
      ;;
    f)
      select_distro_sub_menu "Fedora / CentOS" "$target" "images:fedora/40" "images:fedora/39" "images:centos/9-Stream"
      return
      ;;
    s)
      search_distro_menu "$target"
      return
      ;;
  esac

  if [[ "$c" =~ ^[0-9]+$ ]] && [ "$c" -ge 1 ] && [ "$c" -le "${#available_images[@]}" ]; then
    UBUNTU_IMAGE_RESULT="${available_images[$((c-1))]}"
  else
    UBUNTU_IMAGE_RESULT="$VPS_IMAGE"
  fi
}

add_menu() {
  local count i n name ip port setup effective_ram
  local -a names nums ports ram_modes ram_values cpu_modes cpu_values disk_modes disk_values network_modes network_values images

  read -r -p "How many VPS containers do you want to add? " count
  [[ "$count" =~ ^[1-9][0-9]*$ ]] || { echo "Invalid count."; return; }

  if [ "$count" -gt 1 ]; then
    echo "1) Configure each VPS individually"
    echo "2) Same resource settings for all"
    read -r -p "Choice: " setup
  else
    setup=1
  fi

  if [ "$setup" = 2 ]; then
    ask_ubuntu_version "all new VPS containers" || return; local shared_img=$UBUNTU_IMAGE_RESULT
    ask_ram_mode "all new VPS containers" || return; local shared_rm=$RAM_MODE_RESULT shared_rv=$RAM_VALUE_RESULT
    ask_cpu_mode "all new VPS containers" || return; local shared_cm=$CPU_MODE_RESULT shared_cv=$CPU_VALUE_RESULT
    ask_disk_mode "all new VPS containers" || return; local shared_dm=$DISK_MODE_RESULT shared_dv=$DISK_VALUE_RESULT
    ask_network_mode "all new VPS containers" || return; local shared_nm=$NETWORK_MODE_RESULT shared_nv=$NETWORK_VALUE_RESULT
  fi

  local first_num
  first_num=$(next_num)
  for ((i=1;i<=count;i++)); do
    n=$((first_num + i - 1))
    name="${VPS_PREFIX}${n}"
    port=$(vps_fixed_port "$n")
    names+=("$name"); nums+=("$n"); ports+=("$port")
    if [ "$setup" = 2 ]; then
      images+=("$shared_img")
      ram_modes+=("$shared_rm"); ram_values+=("${shared_rv:-}")
      cpu_modes+=("$shared_cm"); cpu_values+=("${shared_cv:-}")
      disk_modes+=("$shared_dm"); disk_values+=("${shared_dv:-}")
      network_modes+=("$shared_nm"); network_values+=("${shared_nv:-}")
    else
      echo; echo "Resources for $name"
      ask_ubuntu_version "$name" || return; images+=("$UBUNTU_IMAGE_RESULT")
      ask_ram_mode "$name" || return; ram_modes+=("$RAM_MODE_RESULT"); ram_values+=("${RAM_VALUE_RESULT:-}")
      ask_cpu_mode "$name" || return; cpu_modes+=("$CPU_MODE_RESULT"); cpu_values+=("${CPU_VALUE_RESULT:-}")
      ask_disk_mode "$name" || return; disk_modes+=("$DISK_MODE_RESULT"); disk_values+=("${DISK_VALUE_RESULT:-}")
      ask_network_mode "$name" || return; network_modes+=("$NETWORK_MODE_RESULT"); network_values+=("${NETWORK_VALUE_RESULT:-}")
    fi
  done

  local ok=0 failed=0
  for i in "${!names[@]}"; do
    effective_ram="${ram_values[$i]:-$MIN_RAM_MB}"
    if create_vps "${names[$i]}" "${nums[$i]}" "$effective_ram" "${ports[$i]}" \
        "${ram_modes[$i]}" "${cpu_modes[$i]}" "${cpu_values[$i]}" \
        "${disk_modes[$i]}" "${disk_values[$i]}" "${network_modes[$i]}" "${network_values[$i]}" \
        "${images[$i]:-$VPS_IMAGE}"; then
      ok=$((ok+1))
    else
      echo "Creation failed for ${names[$i]}. Rolling back incomplete VPS..."
      remove_port "${ports[$i]}" 2>/dev/null || true
      incus delete "${names[$i]}" --force 2>/dev/null || true
      failed=$((failed+1))
    fi
  done
  echo "Creation summary: Success=$ok | Incomplete/Failed=$failed"
}

# ── Delete Menu (consolidated from delete_menu + bulk_delete_menu) ───────────

delete_vps_menu() {
  local n ip p
  ask_vps_selection || return
  show_selection
  read -r -p "Type DELETE to permanently delete selected VPS containers: " x
  [ "$x" = "DELETE" ] || { echo "Cancelled."; return; }

  for n in "${SELECTED_VPS[@]}"; do
    echo "Deleting $n..."
    ip=$(get_ip "$n"); p=$(get_port "$ip")
    remove_ip "$ip"; [ -n "$p" ] && remove_port "$p"
    [ -n "$ip" ] && port_forward_delete_rules_for_ip "$ip"
    rm -f "/etc/caddy/vpsforge/${n}.caddy"
    incus delete "$n" --force >/dev/null 2>&1 || true
    if incus list -c n --format csv 2>/dev/null | grep -Fxq "$n"; then
      echo "WARNING: $n still appears in Incus after delete attempt."
    else
      echo "Deleted $n"
    fi
  done
  systemctl reload-or-restart caddy >/dev/null 2>&1 || true
  save_iptables
}

# ── Reinstall Menu (consolidated — uses preserve_vps_settings) ───────────────

reinstall_vps_menu() {
  local n num ip port x
  ask_vps_selection || return
  show_selection
  read -r -p "Type REINSTALL to erase and reinstall selected VPS containers: " x
  [ "$x" = "REINSTALL" ] || { echo "Cancelled."; return; }

  for n in "${SELECTED_VPS[@]}"; do
    num=$(get_num "$n")
    ip=$(get_ip "$n")
    port=$(vps_fixed_port "$num")

    preserve_vps_settings "$n"
    print_preserved_settings "$n" "$port"

    remove_ip "$ip"
    remove_port "$port"
    incus delete "$n" --force || { echo "FAILED deleting $n"; continue; }

    if create_vps "$n" "$num" "$PRESERVED_RAM_LIMIT" "$port" \
        "$PRESERVED_RAM_MODE" "$PRESERVED_CPU_MODE" "$PRESERVED_CPU_LIMIT" \
        "$PRESERVED_DISK_MODE" "$PRESERVED_DISK_LIMIT" \
        "$PRESERVED_NETWORK_MODE" "$PRESERVED_NETWORK_LIMIT"; then
      [ "$PRESERVED_USER" = "root" ] || change_vps_username "$n" "$PRESERVED_USER"
      change_vps_password "$n" "$PRESERVED_PASSWORD"
      echo "Reinstall completed for $n with preserved resource settings."
    else
      echo "FAILED reinstalling $n"
    fi
  done
}

# ── State Actions (Start / Stop / Restart) ───────────────────────────────────

bulk_state_action() {
  local action="$1" n
  ask_vps_selection || return
  show_selection
  for n in "${SELECTED_VPS[@]}"; do
    echo "$action $n..."
    incus "$action" "$n" || echo "FAILED: $n"
  done
}

# ── Edit Menus ───────────────────────────────────────────────────────────────

edit_single_vps() {
  local name="$1" c port user pass
  while :; do
    echo
    echo "0) Back"
    echo "1) Change RAM"
    echo "2) Change CPU"
    echo "3) Change Disk"
    echo "4) Change Network Speed"
    echo "5) Change SSH Port"
    echo "6) Change Username"
    echo "7) Change Password"
    read -r -p "Choice: " c
    case "$c" in
      1) ask_ram_mode "$name" && set_ram_mode_for_vps "$name" "$RAM_MODE_RESULT" "$RAM_VALUE_RESULT";;
      2) ask_cpu_mode "$name" && set_cpu_mode_for_vps "$name" "$CPU_MODE_RESULT" "$CPU_VALUE_RESULT";;
      3) ask_disk_mode "$name" && set_disk_mode_for_vps "$name" "$DISK_MODE_RESULT" "$DISK_VALUE_RESULT";;
      4) ask_network_mode "$name" && set_network_mode_for_vps "$name" "$NETWORK_MODE_RESULT" "$NETWORK_VALUE_RESULT";;
      5) read -r -p "New SSH port: " port; change_vps_port "$name" "$port";;
      6) read -r -p "New username: " user; change_vps_username "$name" "$user";;
      7) read -r -s -p "New password: " pass; echo; [ -n "$pass" ] && change_vps_password "$name" "$pass";;
      0) return;;
    esac
  done
}

edit_multiple_vps() {
  local c n sm sv
  while :; do
    echo
    echo "0) Back"
    echo "1) Change RAM"
    echo "2) Change CPU"
    echo "3) Change Disk"
    echo "4) Change Network Speed"
    echo "5) Change Username"
    echo "6) Change Password"
    read -r -p "Choice: " c
    case "$c" in
      1|2|3|4)
        local mode
        echo "1) Configure each VPS individually"
        echo "2) Same setting for all selected VPS"
        read -r -p "Choice: " mode
        for n in "${SELECTED_VPS[@]}"; do
          if [ "$mode" = "2" ] && [ "$n" != "${SELECTED_VPS[0]}" ]; then
            :
          else
            case "$c" in
              1) ask_ram_mode "$n" || continue; sm="$RAM_MODE_RESULT"; sv="$RAM_VALUE_RESULT";;
              2) ask_cpu_mode "$n" || continue; sm="$CPU_MODE_RESULT"; sv="$CPU_VALUE_RESULT";;
              3) ask_disk_mode "$n" || continue; sm="$DISK_MODE_RESULT"; sv="$DISK_VALUE_RESULT";;
              4) ask_network_mode "$n" || continue; sm="$NETWORK_MODE_RESULT"; sv="$NETWORK_VALUE_RESULT";;
            esac
          fi
          case "$c" in
            1) set_ram_mode_for_vps "$n" "$sm" "$sv";;
            2) set_cpu_mode_for_vps "$n" "$sm" "$sv";;
            3) set_disk_mode_for_vps "$n" "$sm" "$sv";;
            4) set_network_mode_for_vps "$n" "$sm" "$sv";;
          esac
        done
        ;;
      5) local value; read -r -p "New username for all: " value; for n in "${SELECTED_VPS[@]}"; do change_vps_username "$n" "$value"; done;;
      6) local value; read -r -s -p "New password for all: " value; echo; for n in "${SELECTED_VPS[@]}"; do change_vps_password "$n" "$value"; done;;
      0) return;;
    esac
  done
}

edit_vps_menu() {
  ask_vps_selection || return
  if [ "${#SELECTED_VPS[@]}" -eq 1 ]; then
    edit_single_vps "${SELECTED_VPS[0]}"
  else
    edit_multiple_vps
  fi
}

# ── Bulk Info Menus ──────────────────────────────────────────────────────────

bulk_details_menu() {
  local n
  ask_vps_selection_enter_all || return
  for n in "${SELECTED_VPS[@]}"; do
    echo
    details "$n"
  done
}

bulk_connection_menu() {
  local n ip p
  ask_vps_selection_enter_all || return
  for n in "${SELECTED_VPS[@]}"; do
    ip=$(get_ip "$n"); p=$(get_port "$ip")
    echo
    echo "================================================"
    echo "VPS Name:    $n"
    echo "Public IP:   $PUBLIC_IP"
    echo "Port:        ${p:--}"
    echo "Username:    $(get_vps_user "$n")"
    echo "Password:    $(get_vps_password "$n")"
    [ -n "$p" ] && echo "SSH Command: ssh $(get_vps_user "$n")@$PUBLIC_IP -p $p"
    echo "================================================"
  done
}

shell_menu() {
  ask_vps_selection "VPS name or number: " || return
  [ "${#SELECTED_VPS[@]}" -eq 1 ] || { echo "Shell supports one VPS at a time."; return; }
  incus exec "${SELECTED_VPS[0]}" -- bash
}

# ── Repair Connection Menu ───────────────────────────────────────────────────

repair_connection_menu() {
  local n num ip saved_port preferred ok=0 failed=0
  local -a repair_list

  mapfile -t repair_list < <(
    incus list -c n --format csv | grep -E "^${VPS_PREFIX}[0-9]+$" | sort -V || true
  )

  [ "${#repair_list[@]}" -gt 0 ] || { echo "No VPS containers found."; return; }

  echo "Repairing all VPS connections..."
  echo

  for n in "${repair_list[@]}"; do
    num=$(get_num "$n")
    ip=$(get_ip "$n")
    preferred=$(vps_fixed_port "$num")
    if ! check_fixed_port_available "$n" "$ip" "$preferred"; then
      echo "FAILED: $n requires fixed port $preferred."
      failed=$((failed+1))
      echo
      continue
    fi
    set_vps_saved_port "$n" "$preferred"

    if repair_vps_connection "$n" "$preferred" </dev/null; then
      set_vps_saved_port "$n" "$preferred"
      ok=$((ok+1))
    else
      failed=$((failed+1))
    fi
    echo
  done

  cleanup_stale_rules
  echo
  echo "Repair summary: Success=$ok | Failed=$failed"
}

# ── Port Forward Interactive Helpers ────────────────────────────────────────

_pf_interactive_add() {
  echo
  echo "--- Add Port Forward Rule ---"

  local target_vps="" internal_ip="" vps_input
  echo "Select target VPS (e.g., 1, vps1) or enter custom IP address:"
  read -r -p "Target VPS / IP: " vps_input
  [ -n "$vps_input" ] || { echo "Cancelled."; return 1; }

  if [[ "$vps_input" =~ ^[0-9]+$ ]]; then
    target_vps="${VPS_PREFIX}${vps_input}"
  else
    target_vps="$vps_input"
  fi

  if incus info "$target_vps" >/dev/null 2>&1; then
    internal_ip=$(get_ip "$target_vps")
    if [ -z "$internal_ip" ]; then
      echo "ERROR: $target_vps is currently stopped or has no IP allocated."
      return 1
    fi
    echo "Selected VPS: $target_vps (Internal IP: $internal_ip)"
  elif [[ "$vps_input" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    internal_ip="$vps_input"
    echo "Using custom IP: $internal_ip"
  else
    echo "ERROR: Invalid VPS or IP address: $vps_input"
    return 1
  fi

  local external_port
  while :; do
    read -r -p "External Port (e.g. 8080): " external_port
    [[ "$external_port" =~ ^[0-9]+$ ]] && [ "$external_port" -ge 1 ] && [ "$external_port" -le 65535 ] && break
    echo "Invalid port. Must be between 1 and 65535."
  done

  local internal_port
  read -r -p "Internal Port [Enter = $external_port]: " internal_port
  [ -n "$internal_port" ] || internal_port="$external_port"
  [[ "$internal_port" =~ ^[0-9]+$ ]] && [ "$internal_port" -ge 1 ] && [ "$internal_port" -le 65535 ] || {
    echo "Invalid internal port."
    return 1
  }

  local proto_choice protocol="tcp"
  echo "Protocol:"
  echo "  1) TCP (default)"
  echo "  2) UDP"
  echo "  3) BOTH (TCP + UDP)"
  read -r -p "Choice [1-3, Enter=1]: " proto_choice
  case "$proto_choice" in
    2) protocol="udp";;
    3) protocol="both";;
    *) protocol="tcp";;
  esac

  local external_ip
  read -r -p "External Bind IP [Enter = 0.0.0.0 (All Interfaces)]: " external_ip
  [ -n "$external_ip" ] || external_ip="0.0.0.0"

  local proto conflict conflict_vps
  for proto in $(resolve_protocols "$protocol"); do
    conflict=$(awk -v p="$proto" -v eip="$external_ip" -v eport="$external_port" -v intip="$internal_ip" -F'|' '
      $1 == p && $2 == eip && $3 == eport && $4 != intip { print $4; exit }
    ' "$PORT_FORWARD_RULES_FILE" 2>/dev/null)
    if [ -n "$conflict" ]; then
      conflict_vps=$(get_vps_name_by_ip "$conflict" 2>/dev/null || echo "$conflict")
      echo ""
      echo "WARNING: Port $external_port ($proto) is already forwarded to $conflict_vps."
      echo "1) Cancel addition"
      echo "2) Steal this port (remove from $conflict_vps, apply to new IP)"
      local choice
      while :; do
        read -r -p "Choice [1-2]: " choice
        case "$choice" in
          1) return 1 ;;
          2) 
            port_forward_cli delete "$proto" "$external_ip" "$external_port" "$conflict" "$internal_port" >/dev/null 2>&1
            break
            ;;
        esac
      done
    fi
  done

  echo
  port_forward_cli add "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
}

_pf_interactive_delete() {
  echo
  echo "--- Delete Port Forward Rule ---"
  local total
  total=$(count_port_forward_rules)
  [ "$total" -gt 0 ] || { echo "No rules to delete."; return 1; }

  local rule_num rule_line
  read -r -p "Select rule # to delete (1-$total, 0=Cancel): " rule_num
  [[ "$rule_num" =~ ^[0-9]+$ ]] && [ "$rule_num" -ge 1 ] && [ "$rule_num" -le "$total" ] || {
    echo "Cancelled."
    return 0
  }

  rule_line=$(get_port_forward_rule_by_index "$rule_num")
  [ -n "$rule_line" ] || { echo "Rule not found."; return 1; }

  local protocol ext_ip ext_port int_ip int_port
  IFS='|' read -r protocol ext_ip ext_port int_ip int_port <<< "$rule_line"
  port_forward_cli delete "$protocol" "$ext_ip" "$ext_port" "$int_ip" "$int_port"
}

_pf_interactive_edit() {
  echo
  echo "--- Edit Port Forward Rule ---"
  local total
  total=$(count_port_forward_rules)
  [ "$total" -gt 0 ] || { echo "No rules to edit."; return 1; }

  local rule_num old_line
  read -r -p "Select rule # to edit (1-$total, 0=Cancel): " rule_num
  [[ "$rule_num" =~ ^[0-9]+$ ]] && [ "$rule_num" -ge 1 ] && [ "$rule_num" -le "$total" ] || {
    echo "Cancelled."
    return 0
  }

  old_line=$(get_port_forward_rule_by_index "$rule_num")
  [ -n "$old_line" ] || { echo "Rule not found."; return 1; }

  local old_proto old_ext_ip old_ext_port old_int_ip old_int_port
  IFS='|' read -r old_proto old_ext_ip old_ext_port old_int_ip old_int_port <<< "$old_line"

  echo "Editing Rule #$rule_num ($old_proto ${old_ext_ip:-0.0.0.0}:${old_ext_port} -> ${old_int_ip}:${old_int_port}):"

  local new_vps_input target_vps new_int_ip
  read -r -p "Target VPS / IP [Enter = $old_int_ip]: " new_vps_input
  if [ -z "$new_vps_input" ]; then
    new_int_ip="$old_int_ip"
  else
    if [[ "$new_vps_input" =~ ^[0-9]+$ ]]; then target_vps="${VPS_PREFIX}${new_vps_input}"; else target_vps="$new_vps_input"; fi
    if incus info "$target_vps" >/dev/null 2>&1; then
      new_int_ip=$(get_ip "$target_vps")
    else
      new_int_ip="$new_vps_input"
    fi
  fi

  local new_ext_port
  read -r -p "External Port [Enter = $old_ext_port]: " new_ext_port
  [ -n "$new_ext_port" ] || new_ext_port="$old_ext_port"

  local new_int_port
  read -r -p "Internal Port [Enter = $old_int_port]: " new_int_port
  [ -n "$new_int_port" ] || new_int_port="$old_int_port"

  local new_proto
  read -r -p "Protocol [tcp/udp/both, Enter = $old_proto]: " new_proto
  [ -n "$new_proto" ] || new_proto="$old_proto"

  local new_ext_ip
  read -r -p "External IP [Enter = ${old_ext_ip:-0.0.0.0}]: " new_ext_ip
  [ -n "$new_ext_ip" ] || new_ext_ip="${old_ext_ip:-0.0.0.0}"

  # Remove old rule & add new rule
  port_forward_cli delete "$old_proto" "$old_ext_ip" "$old_ext_port" "$old_int_ip" "$old_int_port"
  port_forward_cli add "$new_proto" "$new_ext_ip" "$new_ext_port" "$new_int_ip" "$new_int_port"
}

# ── Port Forward Menu ────────────────────────────────────────────────────────

port_forward_menu() {
  local c confirm
  while :; do
    clear
    echo "================================================"
    echo "                  PORT FORWARD"
    echo "================================================"
    echo
    port_forward_list_rules
    echo
    echo "0) Back"
    echo "1) Add Rule"
    echo "2) Edit Rule"
    echo "3) Delete Rule"
    echo "4) Delete ALL Rules"
    echo "5) Active NAT Status"
    echo
    read -r -p "Choice: " c

    case "$c" in
      1) _pf_interactive_add; pause;;
      2) _pf_interactive_edit; pause;;
      3) _pf_interactive_delete; pause;;
      4)
        read -r -p "Are you sure you want to delete ALL port-forward rules? (y/N): " confirm
        if [[ "${confirm,,}" =~ ^y ]]; then
          port_forward_cli delete-all
        fi
        pause
        ;;
      5) port_forward_cli status; pause;;
      0) return;;
      *) sleep 1;;
    esac
  done
}

# ── Snapshots & Backups Menu ────────────────────────────────────────────────

backup_vps_menu() {
  local c n snap_name file_path
  while :; do
    clear
    echo "================================================"
    echo "              SNAPSHOTS & BACKUPS"
    echo "================================================"
    echo
    echo "0) Back"
    echo "1) Create Snapshot"
    echo "2) List Snapshots"
    echo "3) Restore Snapshot"
    echo "4) Delete Snapshot"
    echo "5) Export Full Backup (tar.gz)"
    echo "6) Import Full Backup (tar.gz)"
    echo "7) Inspect Backup File Details"
    echo "8) Update / Overwrite Existing Backup"
    echo "9) Delete Backup File"
    echo
    read -r -p "Choice: " c

    case "$c" in
      1)
        ask_vps_selection "VPS name or number: " || { pause; continue; }
        [ "${#SELECTED_VPS[@]}" -eq 1 ] || { echo "Snapshot supports one VPS at a time."; pause; continue; }
        n="${SELECTED_VPS[0]}"
        read -r -p "Snapshot name [Enter = auto-timestamp]: " snap_name
        create_vps_snapshot "$n" "$snap_name"
        pause
        ;;
      2)
        ask_vps_selection "VPS name or number: " || { pause; continue; }
        [ "${#SELECTED_VPS[@]}" -eq 1 ] || { echo "Supports one VPS at a time."; pause; continue; }
        list_vps_snapshots "${SELECTED_VPS[0]}"
        pause
        ;;
      3)
        ask_vps_selection "VPS name or number: " || { pause; continue; }
        [ "${#SELECTED_VPS[@]}" -eq 1 ] || { echo "Supports one VPS at a time."; pause; continue; }
        n="${SELECTED_VPS[0]}"
        list_vps_snapshots "$n"
        read -r -p "Snapshot name to restore: " snap_name
        [ -n "$snap_name" ] && restore_vps_snapshot "$n" "$snap_name"
        pause
        ;;
      4)
        ask_vps_selection "VPS name or number: " || { pause; continue; }
        [ "${#SELECTED_VPS[@]}" -eq 1 ] || { echo "Supports one VPS at a time."; pause; continue; }
        n="${SELECTED_VPS[0]}"
        list_vps_snapshots "$n"
        read -r -p "Snapshot name to delete: " snap_name
        [ -n "$snap_name" ] && delete_vps_snapshot "$n" "$snap_name"
        pause
        ;;
      5)
        ask_vps_selection "VPS name or number: " || { pause; continue; }
        for n in "${SELECTED_VPS[@]}"; do
          export_vps_backup "$n"
        done
        pause
        ;;
      6)
        if select_backup_file "Select backup file to import: "; then
          import_vps_backup "$SELECTED_BACKUP_FILE"
        fi
        pause
        ;;
      7)
        if select_backup_file "Select backup file to inspect: "; then
          inspect_backup_file "$SELECTED_BACKUP_FILE"
        fi
        pause
        ;;
      8)
        update_vps_backup
        pause
        ;;
      9)
        delete_backup_file
        pause
        ;;
      0) return;;
      *) sleep 1;;
    esac
  done
}

# ── Main Interactive Loop ───────────────────────────────────────────────────

interactive() {
  local c
  load_settings
  while :; do
    dashboard
    c=""
    if [ "$AUTO_REFRESH" = "on" ]; then
      if ! read -r -t "$REFRESH_INTERVAL" -p "Choice: " c; then
        get_network_info
        get_public_ip
        continue
      fi
    else
      read -r -p "Choice: " c
    fi
    echo

    case "$c" in
      1)  add_menu; pause;;
      2)  delete_vps_menu; pause;;
      3)  bulk_state_action start; pause;;
      4)  bulk_state_action stop; pause;;
      5)  bulk_state_action restart; pause;;
      6)  reinstall_vps_menu; pause;;
      7)  edit_vps_menu; pause;;
      8)  bulk_details_menu; pause;;
      9)  shell_menu;;
      10) bulk_connection_menu; pause;;
      11) port_forward_menu; pause;;
      12) proxy_menu;;
      13) backup_vps_menu;;
      14) settings_menu;;
      15) exit 0;;
      *)  sleep 1;;
    esac
  done
}
