#!/bin/bash
# Menu for managing container snapshots, backups, and cloning.
backup_vps_menu() {
  clean_stale_temp_backups >/dev/null 2>&1 || true
  local c
  while :; do
    clear
    echo "================================================"
    echo "              SNAPSHOTS & BACKUPS"
    echo "================================================"
    echo
    echo "0) Back"
    echo "1) Create Snapshot       instant, e.g. before an update"
    echo "2) List Snapshots"
    echo "3) Restore Snapshot      go back to how the VPS was"
    echo "4) Delete Snapshot"
    echo "5) Export Full Backup (tar)   a file you can keep or move to another server"
    echo "6) Import Full Backup (tar/tar.gz)   bring a VPS back from a file"
    echo "7) Inspect Backup File Details"
    echo "8) Update / Overwrite Existing Backup   refresh a backup with the VPS as it is now"
    echo "9) Delete Backup File"
    echo "10) Rename Backup File"
    echo "11) Clean Temp Backup    remove half-finished files"
    echo "12) Clean Orphaned Backups (VPS no longer exists)"
    echo "13) Clone a VPS          instant copy to experiment on (own IP and SSH port)"
    echo
    read -r -p "Choice [0=Back, Enter=1]: " c
    c="${c:-1}"

    case "$c" in
      1) _backup_menu_create_snapshot ;;
      2) _backup_menu_list_snapshots ;;
      3) _backup_menu_restore_snapshot ;;
      4) _backup_menu_delete_snapshot ;;
      5) _backup_menu_export ;;
      6)
        if select_backup_file "Select backup file to import: "; then
          import_vps_backup "$SELECTED_BACKUP_FILE"
          pause
        fi
        ;;
      7)
        if select_backup_file "Select backup file to inspect: "; then
          inspect_backup_file "$SELECTED_BACKUP_FILE"
          pause
        fi
        ;;
      8) update_vps_backup ;;
      9) delete_backup_file ;;
      10) rename_backup_file ;;
      11)
        echo "Running cleanup..."
        clean_stale_temp_backups
        echo "Temporary backups cleaned up successfully."
        pause
        ;;
      12)
        clean_orphaned_backups
        pause
        ;;
      13)
        clone_vps_menu
        pause
        ;;
      0) return;;
      *) sleep 1;;
    esac
  done
}
