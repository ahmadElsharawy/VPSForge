#!/bin/bash

extract_container_name_from_backup_filename() {
  local fname="$1" name
  fname=$(basename "$fname")
  if [[ "$fname" == *-backup-* ]]; then
    name="${fname%%-backup-*}"
  elif [[ "$fname" == *.tar.gz ]]; then
    name="${fname%.tar.gz}"
  elif [[ "$fname" == *.tar ]]; then
    name="${fname%.tar}"
  else
    name="$fname"
  fi
  echo "$name"
}

inspect_backup_file() {
  local file_path="${1:-${SELECTED_BACKUP_FILE:-}}" index_content
  [ -n "$file_path" ] && [ -f "$file_path" ] || { echo "File not found: $file_path"; return 1; }

  local size mtime orig_name orig_ip orig_port ram_lim cpu_lim os_img pfs proxy_b64
  size=$(du -h "$file_path" 2>/dev/null | awk '{print $1}')
  mtime=$(stat -c "%y" "$file_path" 2>/dev/null | cut -d'.' -f1 || echo "-")

  local info_path="${file_path}.info"
  if [ -f "$info_path" ]; then
    index_content=$(cat "$info_path" 2>/dev/null || true)
  else
    echo ""
    local tar_pid progress=0 tmp_meta="/tmp/vpsforge_meta_$$.yaml"
    ( tar -xvf "$file_path" backup/index.yaml -O > "$tmp_meta" ) >/dev/null 2>&1 &
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

  orig_name=$(extract_container_name_from_backup_filename "$file_path")
  [ -n "$orig_name" ] || orig_name=$(echo "$index_content" | awk -F': ' '/^name:/{print $2; exit}' | tr -d '"' | tr -d "'" || echo "-")

  orig_ip=$(echo "$index_content" | awk -F': ' '/user\.vpsforge\.ip:/{print $2; exit}' | tr -d '"' | tr -d "'" || echo "-")
  orig_port=$(echo "$index_content" | awk -F': ' '/user\.vpsforge\.ssh_port:/{print $2; exit}' | tr -d '"' | tr -d "'" || echo "-")
  ram_lim=$(echo "$index_content" | awk -F': ' '/limits\.memory:/{print $2; exit}' | tr -d '"' | tr -d "'" || echo "Unlimited")
  cpu_lim=$(echo "$index_content" | awk -F': ' '/limits\.cpu:/{print $2; exit}' | tr -d '"' | tr -d "'" || echo "Unlimited")
  os_img=$(echo "$index_content" | awk -F': ' '/user\.vpsforge\.image:/{print $2; exit}' | tr -d '"' | tr -d "'" || echo "Ubuntu")
  pfs=$(echo "$index_content" | awk -F': ' '/user\.vpsforge\.port_forwards\.summary:/{print $2; exit}' | tr -d '"' | tr -d "'" || echo "")
  if [ -z "$pfs" ]; then
    pfs=$(echo "$index_content" | awk -F': ' '/user\.vpsforge\.portforwards:/{print $2; exit}' | tr -d '"' | tr -d "'" || echo "-")
  fi
  proxy_b64=$(echo "$index_content" | awk -F': ' '/user\.vpsforge\.proxy:/{print $2; exit}' | tr -d '"' | tr -d "'" || echo "-")

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
  if [ -n "$proxy_b64" ] && [ "$proxy_b64" != "-" ]; then
    local proxy_decoded doms
    proxy_decoded=$(echo "$proxy_b64" | base64 -d 2>/dev/null || true)
    doms=$(echo "$proxy_decoded" | grep -v '^[[:space:]]*$' | grep -v '^[[:space:]]*#' | head -n 1 | sed 's/{//g' | tr ',' ' ' | xargs)
    [ -n "$doms" ] && echo "Linked Domains:  $doms" || echo "Linked Domains:  Configured"
  else
    echo "Linked Domains:  None"
  fi
  echo "================================================"
}
