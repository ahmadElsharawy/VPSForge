#!/bin/bash
# Remove backups, VPSForge's own folder, and the "vpsforge" commands. Runs last.
uninstall_remove_app_files() {
  local keep_backups="${1:-0}"
  echo "[7/7] Removing VPSForge files..."
  if [ "$keep_backups" = "1" ]; then
    echo "  (backups kept in $BACKUP_DIR)"
  else
    uninstall_run rm -rf "$BACKUP_DIR"
  fi
  uninstall_run rm -rf /opt/vpsforge
  uninstall_run rm -f /usr/local/bin/vpsforge /usr/local/bin/VPSForge /usr/local/bin/VPSFORGE /usr/local/bin/vpsforge-update
}
