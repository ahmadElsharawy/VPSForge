#!/bin/bash
# Gathers and displays backup history archives and last restore timestamp for a VPS.
_details_print_backups() {
  local name="$1" bk last_restore
  local -a backup_list=()
  local b_file b_size b_mtime
  while read -r b_file; do
    [ -n "$b_file" ] || continue
    b_size=$(du -h "$b_file" 2>/dev/null | awk '{print $1}')
    b_mtime=$(stat -c "%y" "$b_file" 2>/dev/null | cut -d'.' -f1 || echo "-")
    backup_list+=("$(basename "$b_file") [$b_size | $b_mtime]")
  done < <(find "${BACKUP_DIR:-/opt/vpsforge-backups}" -maxdepth 1 -type f \( -name "${name}-backup-*.tar.gz" -o -name "${name}-backup-*.tar" \) 2>/dev/null | sort -r || true)

  last_restore=$(incus config get "$name" user.vpsforge.last_restore 2>/dev/null || true)
  [ -n "$last_restore" ] || last_restore="Never / Original State"

  echo "── Backups History (${#backup_list[@]}) ────────────────────"
  if [ "${#backup_list[@]}" -gt 0 ]; then
    for bk in "${backup_list[@]}"; do
      echo "  • $bk"
    done
  else
    echo "  None"
  fi
  echo "  Last Restored:  $last_restore"
  echo "================================================================"
}
