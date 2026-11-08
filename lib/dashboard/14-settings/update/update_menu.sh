#!/bin/bash
# VPSForge — Settings: Update / Change Version.

update_menu() {
  local repo_dir app_dir choice target i
  local -a tags

  app_dir=$(get_vpsforge_app_dir)
  repo_dir=$(get_vpsforge_repo_dir)

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
  read -r -p "Choice [0=Cancel, Enter=1]: " choice
  choice="${choice:-1}"

  case "$choice" in
    1)
      vpsforge_perform_update latest
      pause
      ;;
    2)
      if [ ! -d "$repo_dir/.git" ]; then
        echo "Initializing repository..."
        vpsforge_perform_update --check >/dev/null 2>&1 || true
      fi
      git -C "$repo_dir" fetch --tags --prune >/dev/null 2>&1 || true
      mapfile -t tags < <(git -C "$repo_dir" tag --sort=-version:refname 2>/dev/null || true)
      if [ "${#tags[@]}" -eq 0 ]; then
        echo "No release tags found. Updating to latest instead..."
        vpsforge_perform_update latest
        pause
        return
      fi

      echo
      echo "Available versions:"
      for i in "${!tags[@]}"; do
        if [ "${tags[$i]}" = "$VPSFORGE_VERSION" ]; then
          echo "$((i+1))) ${tags[$i]} (current)"
        else
          echo "$((i+1))) ${tags[$i]}"
        fi
      done
      echo

      local v_choice
      read -r -p "Choose version number, or press Enter to cancel: " v_choice
      [ -n "$v_choice" ] || return
      if [[ "$v_choice" =~ ^[0-9]+$ ]] && [ "$v_choice" -ge 1 ] && [ "$v_choice" -le "${#tags[@]}" ]; then
        target="${tags[$((v_choice-1))]}"
        vpsforge_perform_update "$target"
        pause
      else
        echo "Invalid choice."
        pause
      fi
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

