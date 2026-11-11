#!/bin/bash
# Inspect and display metadata from a backup archive or cached .info file.
inspect_backup_file() {
  local file_path="${1:-${SELECTED_BACKUP_FILE:-}}" index_content
  [ -n "$file_path" ] && [ -f "$file_path" ] || { echo "File not found: $file_path"; return 1; }

  local size mtime orig_name orig_ip orig_port ram_lim cpu_lim os_img pfs proxy_b64
  size=$(du -h "$file_path" 2>/dev/null | awk '{print $1}')
  mtime=$(stat -c "%y" "$file_path" 2>/dev/null | cut -d'.' -f1 || echo "-")

  _inspect_backup_load_metadata "$file_path"

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

  _inspect_backup_print_details "$file_path" "$size" "$mtime" "$orig_name" "$orig_ip" "$orig_port" \
    "$ram_lim" "$cpu_lim" "$os_img" "$pfs" "$proxy_b64"
}
