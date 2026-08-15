#!/bin/bash

backup_vps_menu() {
  clean_stale_temp_backups >/dev/null 2>&1 || true
  local c n snap_name file_path
  while :; do
    clear
    echo "================================================"
    echo "              SNAPSHOTS & BACKUPS"
    echo "================================================"
    echo
    echo "0) Back"
    echo "1) Create Snapshot"
    echo "2) List Snapshots"
    echo "3) Restore Snapshot"
    echo "4) Delete Snapshot"
    echo "5) Export Full Backup (tar)"
    echo "6) Import Full Backup (tar/tar.gz)"
    echo "7) Inspect Backup File Details"
    echo "8) Update / Overwrite Existing Backup"
    echo "9) Delete Backup File"
    echo "10) Rename Backup File"
    echo "11) Clean Temp Backup"
    echo
    read -r -p "Choice [0=Back, Enter=1]: " c
    c="${c:-1}"

    case "$c" in
      1)
        ask_vps_selection "VPS name or number [0=Back, Enter=1]: " || continue
        [ "${#SELECTED_VPS[@]}" -eq 1 ] || { echo "Snapshot supports one VPS at a time."; pause; continue; }
        n="${SELECTED_VPS[0]}"
        read -r -p "Snapshot name [Enter = auto-timestamp]: " snap_name
        create_vps_snapshot "$n" "$snap_name"
        pause
        ;;
      2)
        ask_vps_selection "VPS name or number [0=Back, Enter=1]: " || continue
        [ "${#SELECTED_VPS[@]}" -eq 1 ] || { echo "Supports one VPS at a time."; pause; continue; }
        list_vps_snapshots "${SELECTED_VPS[0]}"
        pause
        ;;
      3)
        ask_vps_selection "VPS name or number [0=Back, Enter=1]: " || continue
        [ "${#SELECTED_VPS[@]}" -eq 1 ] || { echo "Supports one VPS at a time."; pause; continue; }
        n="${SELECTED_VPS[0]}"
        if select_vps_snapshot "$n" "Snapshot number or name to restore: "; then
          restore_vps_snapshot "$n" "$SELECTED_SNAPSHOT"
          pause
        fi
        ;;
      4)
        ask_vps_selection "VPS name or number [0=Back, Enter=1]: " || continue
        [ "${#SELECTED_VPS[@]}" -eq 1 ] || { echo "Supports one VPS at a time."; pause; continue; }
        n="${SELECTED_VPS[0]}"
        if select_vps_snapshots "$n" "Snapshot number(s) to delete (e.g. 1, 1,2, 1-3, or A for All, 0=Cancel): "; then
          for snap_name in "${SELECTED_SNAPSHOTS[@]}"; do
            delete_vps_snapshot "$n" "$snap_name"
          done
          pause
        fi
        ;;
      5)
        ask_vps_selection "VPS name or number [0=Back, Enter=1]: " || continue
        for n in "${SELECTED_VPS[@]}"; do
          export_vps_backup "$n"
        done
        pause
        ;;
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
      8)
        update_vps_backup
        ;;
      9)
        delete_backup_file
        ;;
      10)
        rename_backup_file
        ;;
      11)
        echo "Running cleanup..."
        clean_stale_temp_backups
        echo "Temporary backups cleaned up successfully."
        pause
        ;;
      0) return;;
      *) sleep 1;;
    esac
  done
}
