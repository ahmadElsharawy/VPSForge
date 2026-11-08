#!/bin/bash
# Delete every backup file (and its .info) that belongs to VPS <name>.
delete_backups_for_vps() {
  local name="${1:?usage: delete_backups_for_vps <name>}" file
  while read -r file; do
    [ -n "$file" ] || continue
    rm -f "$file" "${file}.info"
    echo "  removed backup $(basename "$file")"
  done < <(list_backups_for_vps "$name")
}
