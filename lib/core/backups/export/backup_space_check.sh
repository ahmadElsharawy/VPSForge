#!/bin/bash
# Before exporting a backup, check the server has enough free disk for it.
# Prints a clear ERROR (and returns 1) when it does not. Backups are compressed,
# so this uses the worst case (uncompressed size) plus a small safety margin.
#   backup_space_check <vps_name>
backup_space_check() {
  local name="${1:?vps}" used_gb free_gb needed_gb
  mkdir -p "$BACKUP_DIR"
  used_gb=$(get_vps_disk_usage_gb "$name" 2>/dev/null || echo 0)
  free_gb=$(df -BG --output=avail "$BACKUP_DIR" 2>/dev/null | tail -1 | tr -dc '0-9')
  needed_gb=$(awk -v u="${used_gb:-0}" 'BEGIN { printf "%d", u + 1 }')
  [[ "$free_gb" =~ ^[0-9]+$ ]] || return 0
  if [ "$free_gb" -lt "$needed_gb" ]; then
    echo "ERROR: Not enough free disk space for this backup: about ${needed_gb}GB needed, only ${free_gb}GB free."
    return 1
  fi
  return 0
}
