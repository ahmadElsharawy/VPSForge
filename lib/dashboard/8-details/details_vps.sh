#!/bin/bash

details() {
  local name="$1"
  local status ram cpu disk network ip port username created_at net_io last_restore
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

  ip=$(get_ip "$name" 2>/dev/null || true); [ -n "$ip" ] || ip="-"

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
  net_io=$(get_vps_network_io_display "$name" 2>/dev/null || echo "-")

  created_at=$(incus query "/1.0/instances/$name" 2>/dev/null | python3 -c 'import sys, json; print(json.load(sys.stdin).get("created_at","")[:19].replace("T"," "))' 2>/dev/null || true)
  [ -n "$created_at" ] || created_at="Unknown"

  last_restore=$(incus config get "$name" user.vpsforge.last_restore 2>/dev/null || true)
  [ -n "$last_restore" ] || last_restore="Never / Original State"

  # Gather Port Forwarding Rules for this container
  local -a pf_rules=()
  if [ -f "$PORT_FORWARD_RULES_FILE" ] && [ "$ip" != "-" ]; then
    local proto eip eport intip intport proto_upper
    while IFS='|' read -r proto eip eport intip intport; do
      [ "$intip" = "$ip" ] || continue
      proto_upper=$(echo "$proto" | tr '[:lower:]' '[:upper:]')
      pf_rules+=("$proto_upper ${eip:-0.0.0.0}:$eport -> $intip:$intport")
    done < "$PORT_FORWARD_RULES_FILE"
  fi

  # Gather Proxy Domains (Caddy)
  local -a proxy_domains=()
  local caddy_file="/etc/caddy/vpsforge/${name}.caddy"
  if [ -f "$caddy_file" ]; then
    local line_domain
    while read -r line_domain; do
      if [[ "$line_domain" =~ ^([a-zA-Z0-9_.-]+)[[:space:]]*\{ ]]; then
        proxy_domains+=("${BASH_REMATCH[1]}")
      fi
    done < "$caddy_file"
  fi

  # Gather Snapshots
  local -a snapshot_list=()
  local s_name s_date
  while IFS=',' read -r s_name s_date rest; do
    [ -n "$s_name" ] || continue
    snapshot_list+=("$s_name ($s_date)")
  done < <(incus snapshot list "$name" --format csv 2>/dev/null || true)

  # Gather Backups
  local -a backup_list=()
  local b_file b_size b_mtime
  while read -r b_file; do
    [ -n "$b_file" ] || continue
    b_size=$(du -h "$b_file" 2>/dev/null | awk '{print $1}')
    b_mtime=$(stat -c "%y" "$b_file" 2>/dev/null | cut -d'.' -f1 || echo "-")
    backup_list+=("$(basename "$b_file") [$b_size | $b_mtime]")
  done < <(find "${BACKUP_DIR:-/opt/vpsforge-backups}" -maxdepth 1 -type f \( -name "${name}-backup-*.tar.gz" -o -name "${name}-backup-*.tar" -o -name "${name}_*.tar.gz" -o -name "${name}_*.tar" \) 2>/dev/null | sort -r || true)

  local traffic_status
  traffic_status=$(incus config get "$name" user.vpsforge.traffic.status 2>/dev/null || true)

  echo "================================================================"
  echo "                VPS DETAILS INSPECTOR: $name"
  echo "================================================================"
  if [ -n "$traffic_status" ]; then
    echo "⚠️  WARNING: TRAFFIC QUOTA EXCEEDED! Status: $traffic_status"
    echo "----------------------------------------------------------------"
  fi
  echo "── System & Identity ───────────────────────────────────────────"
  echo "  Name:           $name"
  echo "  Status:         $status"
  echo "  Created At:     $created_at"
  echo "  Internal IP:    $ip"
  echo "  SSH Port:       $port"
  echo "  Username:       $username"
  if [ "$port" != "-" ]; then
    echo "  SSH Command:    ssh ${username}@${PUBLIC_IP} -p ${port}"
  fi
  echo
  echo "── Resources & Usage ───────────────────────────────────────────"
  echo "  RAM Usage:      $ram ($([ -n "$ram_limit" ] && echo "Limited: ${ram_limit}MB" || echo "Unlimited"))"
  echo "  CPU Cores:      $cpu ($([ -n "$cpu_limit" ] && echo "Limited: ${cpu_limit} core(s)" || echo "Unlimited"))"
  echo "  Disk Usage:     $disk ($([ -n "$disk_limit" ] && echo "Limited: ${disk_limit}GB" || echo "Unlimited"))"
  echo "  Network Limit:  $network ($([ -n "$network_limit" ] && echo "Limited: ${network_limit}Mbit" || echo "Unlimited"))"
  echo "  Network I/O:    $net_io"
  echo
  echo "── Configured Port-Forward Rules (${#pf_rules[@]}) ──────────────────────"
  if [ "${#pf_rules[@]}" -gt 0 ]; then
    local r
    for r in "${pf_rules[@]}"; do
      echo "  • $r"
    done
  else
    echo "  None"
  fi
  echo
  echo "── Reverse Proxy & Domains (${#proxy_domains[@]}) ─────────────────────────"
  if [ "${#proxy_domains[@]}" -gt 0 ]; then
    local pd
    for pd in "${proxy_domains[@]}"; do
      echo "  • https://$pd"
    done
  else
    echo "  None"
  fi
  echo
  echo "── Snapshots History (${#snapshot_list[@]}) ──────────────────────────"
  if [ "${#snapshot_list[@]}" -gt 0 ]; then
    local sn
    for sn in "${snapshot_list[@]}"; do
      echo "  • $sn"
    done
  else
    echo "  None"
  fi
  echo
  echo "── Backups History (${#backup_list[@]}) ────────────────────────────"
  if [ "${#backup_list[@]}" -gt 0 ]; then
    local bk
    for bk in "${backup_list[@]}"; do
      echo "  • $bk"
    done
  else
    echo "  None"
  fi
  echo "  Last Restored:  $last_restore"
  echo "================================================================"
}

bulk_details_menu() {
  local n
  ask_vps_selection_enter_all || return
  for n in "${SELECTED_VPS[@]}"; do
    echo
    details "$n"
  done
}
