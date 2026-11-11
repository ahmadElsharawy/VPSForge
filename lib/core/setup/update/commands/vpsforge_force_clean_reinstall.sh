#!/bin/bash
# Cleanly purge old files, re-clone from GitHub, and rebuild the active installation.
vpsforge_force_clean_reinstall() {
  local app_dir repo_dir repo_url default_repo="https://github.com/ahmadElsharawy/VPSForge.git"
  local short_sha ver
  app_dir=$(get_vpsforge_app_dir)
  repo_dir=$(get_vpsforge_repo_dir)
  repo_url="${VPSFORGE_REPO_URL:-$default_repo}"

  echo "================================================"
  echo "       VPSFORGE FORCE CLEAN RE-SYNC"
  echo "================================================"
  echo "This will cleanly purge old files, re-clone from GitHub, and rebuild the active installation."
  echo "Your VPS containers, network settings, and backups will be 100% PRESERVED."
  echo

  cd /root 2>/dev/null || cd /tmp 2>/dev/null || cd /

  # 1. Clean all legacy backup and cache files
  rm -rf "$app_dir"/lib.backup* "$app_dir"/vpsforge.sh.backup* "$app_dir"/.lib_staging_* "$app_dir"/.vpsforge.sh_staging_* "$app_dir"/raw_incus.txt "$app_dir"/ubuntu_images_cache.txt 2>/dev/null || true

  # 2. Re-clone repository fresh
  _clone_fresh_repo "$repo_url" "$repo_dir" "$app_dir" || return 1

  # 3. Synchronize cleanly to active installation
  short_sha=$(git -C "$repo_dir" rev-parse --short HEAD 2>/dev/null || echo "unknown")
  echo "Synchronizing fresh code (commit $short_sha)..."
  if ! _apply_staged_code_sync "$app_dir" "$repo_dir" "$short_sha"; then
    echo "ERROR: Clean synchronization failed." >&2
    return 1
  fi

  # 4. Refresh symlinks and wrappers
  _refresh_install_symlinks "$app_dir"

  # 5. Clean any residual backups
  rm -rf "$app_dir"/lib.backup* "$app_dir"/vpsforge.sh.backup* 2>/dev/null || true

  # 6. Run migrations
  cleanup_legacy_dockerenv_markers 2>/dev/null || true

  ver=$(sed -n 's/^VPSFORGE_VERSION="\(v[0-9][0-9.]*\)"/\1/p' "$app_dir/vpsforge.sh" 2>/dev/null | head -n1)

  echo
  echo "================================================"
  echo " Clean re-sync completed successfully."
  echo " Version:  ${ver:-unknown}"
  echo " Commit:   $short_sha"
  echo " Status:   CLEAN & SYNCED"
  echo "================================================"
  echo

  if [ -t 0 ] && [ -n "${VPSFORGE_VERSION:-}" ]; then
    echo "Reloading VPSForge in current session..."
    sleep 1
    exec "$app_dir/vpsforge.sh"
  fi
  return 0
}
