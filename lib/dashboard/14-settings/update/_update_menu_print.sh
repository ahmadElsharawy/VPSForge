#!/bin/bash
# Displays the update menu header, version, and action options.
_update_menu_print() {
  echo "================================================"
  echo "           VPSFORGE VERSION MANAGER"
  echo "================================================"
  echo "Current Version: $VPSFORGE_VERSION"
  echo "Installed Commit: $(get_active_installed_commit)"
  echo
  echo "1) Clean Update to Latest Release (origin/main)"
  echo "2) Select Specific Tagged Release / Version"
  echo "3) Force Clean Re-Sync from GitHub (Fresh Clone & Purge Old Files)"
  echo "4) Check Update & Synchronization Status"
  echo "0) Back / Cancel"
  echo
}
