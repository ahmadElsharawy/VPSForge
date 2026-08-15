#!/bin/bash

export_vps_backup() {
  local name="$1" file_path default_name custom_name
  local ip port ram cpu image pfs proxy_b64 domains confirm
  sync_vps_metadata "$name"

  # Gather details for preview
  ip=$(get_ip "$name" 2>/dev/null || echo "-")
  port=$(get_vps_saved_port "$name" 2>/dev/null || echo "-")
  ram=$(incus config get "$name" limits.memory 2>/dev/null || echo "Unlimited")
  cpu=$(incus config get "$name" limits.cpu 2>/dev/null || echo "Unlimited")
  image=$(incus config get "$name" user.vpsforge.image 2>/dev/null || echo "Ubuntu")
  pfs=$(incus config get "$name" user.vpsforge.port_forwards.summary 2>/dev/null || echo "None")
  proxy_b64=$(incus config get "$name" user.vpsforge.proxy 2>/dev/null || echo "-")

  [ -n "$ram" ] || ram="Unlimited"
  [ -n "$cpu" ] || cpu="Unlimited"
  [ -n "$image" ] || image="Ubuntu"
  [ -n "$pfs" ] || pfs="None"

  domains="None"
  if [ -n "$proxy_b64" ] && [ "$proxy_b64" != "-" ]; then
    local proxy_decoded
    proxy_decoded=$(echo "$proxy_b64" | base64 -d 2>/dev/null || true)
    domains=$(echo "$proxy_decoded" | awk '/\{/{print $1}' | tr '\n' ' ' | sed 's/ *$//')
    [ -n "$domains" ] || domains="Configured"
  fi

  clear
  echo "================================================"
  echo "            BACKUP PREVIEW: $name"
  echo "================================================"
  echo "VPS Name:        $name"
  echo "Internal IP:     $ip"
  echo "SSH Port:        $port"
  echo "RAM Limit:       $ram"
  echo "CPU Limit:       $cpu"
  echo "OS Image:        $image"
  echo "Forwarded Ports: $(echo "$pfs" | tr ';' ' ')"
  echo "Linked Domains:  $domains"
  echo "================================================"
  
  read -r -p "Press Enter to proceed with backup (or '0' to cancel): " confirm </dev/tty
  if [ "$confirm" = "0" ]; then
    echo "Backup cancelled."
    return 0
  fi

  mkdir -p "$BACKUP_DIR"
  default_name="${name}-backup-$(date +%Y%m%d-%H%M%S).tar"
  read -r -p "Enter backup filename [default: $default_name]: " custom_name </dev/tty
  if [ -n "$custom_name" ]; then
    if [[ "$custom_name" != *.tar && "$custom_name" != *.tar.gz ]]; then
      custom_name="${custom_name}.tar"
    fi
    file_path="${BACKUP_DIR}/${custom_name}"
  else
    file_path="${BACKUP_DIR}/${default_name}"
  fi
  local tmp_dir="${BACKUP_DIR}/.tmp"
  mkdir -p "$tmp_dir"
  local tmp_file_path="${tmp_dir}/$(basename "$file_path")"

  # Automatically disable and remove non-functional container swapfiles to prevent backup bloat
  incus exec "$name" -- sh -c "swapoff /swapfile 2>/dev/null || true"
  incus exec "$name" -- sh -c "rm -f /swapfile 2>/dev/null || true"

  echo "Exporting backup for $name to temporary storage..."
  if incus export "$name" "$tmp_file_path"; then
    if mv "$tmp_file_path" "$file_path"; then
      echo "Backup saved: $file_path"
      incus config show "$name" --expanded > "${file_path}.info" 2>/dev/null || true
    else
      echo "ERROR: Failed to move backup to final destination."
      return 1
    fi
  else
    echo "ERROR: Backup export failed."
    return 1
  fi
}
