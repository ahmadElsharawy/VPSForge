#!/bin/bash
# CLI & Menu dispatcher for updates
vpsforge_perform_update() {
  local target="${1:-latest}"
  local app_dir repo_dir repo_url default_repo="https://github.com/ahmadElsharawy/VPSForge.git"
  local target_sha target_version short_sha is_interactive=0

  app_dir=$(get_vpsforge_app_dir)
  repo_dir=$(get_vpsforge_repo_dir)
  repo_url="${VPSFORGE_REPO_URL:-$default_repo}"

  # Dispatch helper flags
  case "$target" in
    --list|-l|list)
      vpsforge_list_versions
      return 0
      ;;
    --check|-c|check)
      vpsforge_check_update_status
      return 0
      ;;
    --status|-s|status)
      vpsforge_print_status
      return 0
      ;;
    --clean|-clean|clean)
      vpsforge_force_clean_reinstall
      return 0
      ;;
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

  # 1. Ensure repository exists
  if [ ! -d "$repo_dir/.git" ]; then
    echo "Cloning canonical repository from $repo_url..."
    mkdir -p "$(dirname "$repo_dir")"
    rm -rf "$repo_dir"
    if ! git clone "$repo_url" "$repo_dir"; then
      echo "ERROR: Failed to clone repository from $repo_url." >&2
      return 1
    fi
  fi

  # 2. Check for uncommitted changes in repo working tree
  if [ -n "$(git -C "$repo_dir" status --porcelain 2>/dev/null || true)" ]; then
    local stash_name="vpsforge-auto-stash-$(date +%Y%m%d_%H%M%S)"
    echo "WARNING: Uncommitted changes detected in $repo_dir."
    echo "Saving changes safely to Git stash ($stash_name)..."
    git -C "$repo_dir" stash push -u -m "$stash_name" >/dev/null 2>&1 || true
  fi

  # 3. Check for local unpushed commits and back them up
  local unpushed
  unpushed=$(git -C "$repo_dir" rev-list --count '@{u}..HEAD' 2>/dev/null || true)
  [[ "$unpushed" =~ ^[0-9]+$ ]] || unpushed=0
  if [ "$unpushed" -gt 0 ]; then
    local backup_branch="backup-local-$(date +%Y%m%d_%H%M%S)"
    echo "Notice: $unpushed local commit(s) found. Creating backup branch '$backup_branch'..."
    git -C "$repo_dir" branch -f "$backup_branch" HEAD 2>/dev/null || true
  fi

  # 4. Fetch all remote branches and tags
  echo "Fetching latest tags and commits from origin..."
  # Unshallow if it was a shallow clone
  if [ -f "$repo_dir/.git/shallow" ]; then
    git -C "$repo_dir" fetch --unshallow --all --tags >/dev/null 2>&1 || true
  fi
  git -C "$repo_dir" fetch --all --tags --prune --force >/dev/null 2>&1 || {
    echo "WARNING: Fetch failed or network unavailable; checking local repository objects..."
  }

  # 5. Resolve target ref
  if [ "$target" = "latest" ] || [ -z "$target" ] || [ "$target" = "main" ]; then
    # Default: latest commit on origin/main or origin/HEAD
    target_sha=$(git -C "$repo_dir" rev-parse origin/main 2>/dev/null || git -C "$repo_dir" rev-parse origin/HEAD 2>/dev/null || git -C "$repo_dir" rev-parse HEAD 2>/dev/null || true)
  elif git -C "$repo_dir" rev-parse "refs/tags/$target" >/dev/null 2>&1; then
    target_sha=$(git -C "$repo_dir" rev-parse "refs/tags/$target^{commit}" 2>/dev/null || true)
  elif git -C "$repo_dir" rev-parse "origin/$target" >/dev/null 2>&1; then
    target_sha=$(git -C "$repo_dir" rev-parse "origin/$target^{commit}" 2>/dev/null || true)
  else
    target_sha=$(git -C "$repo_dir" rev-parse "$target^{commit}" 2>/dev/null || true)
  fi

  if [ -z "$target_sha" ]; then
    echo "ERROR: Unable to resolve target version or commit '$target'." >&2
    return 1
  fi

  short_sha=$(git -C "$repo_dir" rev-parse --short "$target_sha" 2>/dev/null || echo "$target_sha")
  echo "Target resolved: $target ($short_sha)"

  # 6. Checkout target ref in repo
  echo "Checking out $short_sha in $repo_dir..."
  if ! git -C "$repo_dir" checkout -f "$target_sha" >/dev/null 2>&1; then
    echo "ERROR: Failed to checkout $target_sha in $repo_dir." >&2
    return 1
  fi

  target_version=$(sed -n 's/^VPSFORGE_VERSION="\(v[0-9][0-9.]*\)"/\1/p' "$repo_dir/vpsforge.sh" 2>/dev/null | head -n1)
  target_version="${target_version:-$short_sha}"

  # 7. Apply staged synchronization to active installation
  echo "Applying atomic synchronization to $app_dir..."
  if ! _apply_staged_code_sync "$app_dir" "$repo_dir" "$short_sha"; then
    echo "================================================"
    echo " ERROR: Update failed: active installation was not updated."
    echo "================================================"
    return 1
  fi

  # 8. Refresh symlinks
  mkdir -p /usr/local/bin
  ln -sf "$app_dir/vpsforge.sh" /usr/local/bin/vpsforge
  ln -sf "$app_dir/vpsforge.sh" /usr/local/bin/VPSForge
  ln -sf "$app_dir/vpsforge.sh" /usr/local/bin/VPSFORGE
  
  cat > /usr/local/bin/vpsforge-update <<'UPD_WRAPPER'
#!/bin/bash
set -euo pipefail
APP="/opt/vpsforge/vpsforge.sh"
if [ ! -x "$APP" ]; then
  APP="$(command -v vpsforge 2>/dev/null || echo "")"
fi
[ -n "$APP" ] && [ -x "$APP" ] || { echo "ERROR: VPSForge executable not found."; exit 1; }
exec "$APP" update "$@"
UPD_WRAPPER
  chmod +x /usr/local/bin/vpsforge-update

  # 9. Run setup migrations from updated code
  if [ -f "$app_dir/lib/load_vpsforge_lib.sh" ]; then
    # shellcheck disable=SC1091
    source "$app_dir/lib/load_vpsforge_lib.sh"
    load_vpsforge_lib "$app_dir/lib"
    cleanup_legacy_dockerenv_markers 2>/dev/null || true
  fi

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

  # If running in interactive shell / terminal, offer immediate re-exec
  if [ -t 0 ] && [ -n "${VPSFORGE_VERSION:-}" ]; then
    echo "Reloading VPSForge in current session..."
    sleep 1
    exec "$app_dir/vpsforge.sh"
  fi
  return 0
}
