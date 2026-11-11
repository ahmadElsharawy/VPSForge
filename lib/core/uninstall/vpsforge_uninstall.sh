#!/bin/bash
# Remove VPSForge and everything it created, returning the server to how it was.
#   vpsforge uninstall [--dry-run] [--yes] [--keep-backups]
vpsforge_uninstall() {
  local assume_yes=0 keep_backups=0 arg
  UNINSTALL_DRY_RUN=0
  for arg in "$@"; do
    case "$arg" in
      --dry-run)      UNINSTALL_DRY_RUN=1;;
      --yes|-y)       assume_yes=1;;
      --keep-backups) keep_backups=1;;
      *) echo "Unknown option: $arg"; echo "Usage: vpsforge uninstall [--dry-run] [--yes] [--keep-backups]"; return 1;;
    esac
  done

  echo "================================================"
  echo "            VPSFORGE FULL UNINSTALL"
  echo "================================================"
  echo "This removes: all VPS containers + snapshots, backups, the storage pool,"
  echo "the bridge, firewall rules, proxy configs, cron/system settings, and VPSForge itself."
  [ "$keep_backups" = "1" ] && echo "(backups will be kept)"
  [ "$UNINSTALL_DRY_RUN" = "1" ] && echo "DRY RUN: nothing will be changed, only listed."
  echo

  _uninstall_confirm_prompt "$assume_yes" || return 1

  uninstall_remove_containers || return 1
  uninstall_remove_firewall
  uninstall_remove_storage
  uninstall_remove_system_files
  uninstall_remove_caddy
  uninstall_remove_packages
  uninstall_remove_app_files "$keep_backups"

  if [ "$UNINSTALL_DRY_RUN" = "1" ]; then
    echo
    echo "Dry run finished. Nothing was changed."
    return 0
  fi
  uninstall_verify_clean
}
