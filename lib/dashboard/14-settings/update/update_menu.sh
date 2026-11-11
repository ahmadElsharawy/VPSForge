#!/bin/bash
# Displays the version manager menu for updating or switching VPSForge releases.

update_menu() {
  local repo_dir choice
  repo_dir=$(get_vpsforge_repo_dir)

  _update_menu_print
  read -r -p "Choice [0=Cancel, Enter=1]: " choice
  choice="${choice:-1}"

  case "$choice" in
    1)
      vpsforge_with_update_lock vpsforge_perform_update latest
      pause
      ;;
    2)
      _update_select_tagged_release "$repo_dir"
      ;;
    3)
      vpsforge_force_clean_reinstall
      pause
      ;;
    4)
      echo
      vpsforge_check_update_status
      echo
      pause
      ;;
    0)
      return
      ;;
    *)
      echo "Invalid choice."
      sleep 1
      ;;
  esac
}
