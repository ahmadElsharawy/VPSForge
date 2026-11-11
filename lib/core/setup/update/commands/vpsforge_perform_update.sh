#!/bin/bash
# Fetch and apply code updates from the canonical git repository.
vpsforge_perform_update() {
  local target="${1:-latest}"
  local app_dir repo_dir repo_url default_repo="https://github.com/ahmadElsharawy/VPSForge.git"
  local target_sha target_version short_sha

  app_dir=$(get_vpsforge_app_dir)
  repo_dir=$(get_vpsforge_repo_dir)
  repo_url="${VPSFORGE_REPO_URL:-$default_repo}"

  # Dispatch helper flags
  case "$target" in
    --list|-l|list)         vpsforge_list_versions; return 0 ;;
    --check|-c|check)       vpsforge_check_update_status; return 0 ;;
    --status|-s|status)     vpsforge_print_status; return 0 ;;
    --clean|-clean|clean)   vpsforge_force_clean_reinstall; return 0 ;;
  esac

  echo "================================================"
  echo "           VPSFORGE UPDATE ENGINE"
  echo "================================================"
  echo "Active installation path: $app_dir"
  echo "Repository path:          $repo_dir"
  echo

  # Ensure safe CWD
  cd /root 2>/dev/null || cd /tmp 2>/dev/null || cd /

  # Ensure Git is installed
  command -v git >/dev/null 2>&1 || {
    echo "ERROR: 'git' is required to perform updates." >&2
    return 1
  }

  _prepare_update_repo "$repo_dir" "$repo_url" || return 1

  target_sha=$(_resolve_target_ref "$repo_dir" "$target")
  if [ -z "$target_sha" ]; then
    echo "ERROR: Unable to resolve target version or commit '$target'." >&2
    return 1
  fi

  short_sha=$(git -C "$repo_dir" rev-parse --short "$target_sha" 2>/dev/null || echo "$target_sha")
  echo "Target resolved: $target ($short_sha)"

  echo "Checking out $short_sha in $repo_dir..."
  if ! git -C "$repo_dir" checkout -f "$target_sha" >/dev/null 2>&1; then
    echo "ERROR: Failed to checkout $target_sha in $repo_dir." >&2
    return 1
  fi

  target_version=$(sed -n 's/^VPSFORGE_VERSION="\(v[0-9][0-9.]*\)"/\1/p' "$repo_dir/vpsforge.sh" 2>/dev/null | head -n1)
  target_version="${target_version:-$short_sha}"

  echo "Applying atomic synchronization to $app_dir..."
  if ! _apply_staged_code_sync "$app_dir" "$repo_dir" "$short_sha"; then
    echo "================================================"
    echo " ERROR: Update failed: active installation was not updated."
    echo "================================================"
    return 1
  fi

  _refresh_install_symlinks "$app_dir"
  _apply_update_migrations "$app_dir"

  echo
  echo "================================================"
  echo " Update successful"
  echo " Version:                        $target_version"
  echo " Commit:                         $short_sha"
  echo " Active path:                    $app_dir"
  echo " Repository:                     $repo_dir"
  echo " Source and active installation: SYNCED"
  echo "================================================"
  echo

  # Tell vpsforge_with_update_lock that the code changed (it reloads VPSForge after letting go of the lock)
  [ -n "${VPSFORGE_UPDATE_DONE_FILE:-}" ] && : > "$VPSFORGE_UPDATE_DONE_FILE"
  # If running in interactive shell / terminal, offer immediate re-exec
  if [ -t 0 ] && [ -n "${VPSFORGE_VERSION:-}" ] && [ -z "${VPSFORGE_UPDATE_DONE_FILE:-}" ]; then
    echo "Reloading VPSForge in current session..."
    sleep 1
    exec "$app_dir/vpsforge.sh"
  fi
  return 0
}
