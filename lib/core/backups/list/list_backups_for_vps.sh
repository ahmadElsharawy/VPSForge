#!/bin/bash
# Print the backup files (tar/tar.gz) that belong to VPS <name>, one per line.
list_backups_for_vps() {
  local name="${1:?usage: list_backups_for_vps <name>}"
  [ -d "$BACKUP_DIR" ] || return 0
  find "$BACKUP_DIR" -maxdepth 1 -type f \
    \( -name "${name}-backup-*.tar" -o -name "${name}-backup-*.tar.gz" \) \
    2>/dev/null | sort
}
