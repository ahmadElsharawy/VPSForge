#!/bin/bash
# VPSForge — Centralized Update & Synchronization Engine.
# Ensures a single source of truth between /opt/vpsforge/repo and /opt/vpsforge.

get_vpsforge_app_dir() {
  if [ -n "${VPSFORGE_SCRIPT_DIR:-}" ] && [ -d "$VPSFORGE_SCRIPT_DIR" ]; then
    echo "$VPSFORGE_SCRIPT_DIR"
  elif [ -d "/opt/vpsforge" ]; then
    echo "/opt/vpsforge"
  else
    cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../.." && pwd
  fi
}

get_vpsforge_repo_dir() {
  local app_dir
  app_dir=$(get_vpsforge_app_dir)
  if [ -d "$app_dir/repo/.git" ]; then
    echo "$app_dir/repo"
  elif [ -d "$app_dir/.git" ]; then
    echo "$app_dir"
  else
    echo "$app_dir/repo"
  fi
}

get_active_installed_commit() {
  local app_dir
  app_dir=$(get_vpsforge_app_dir)
  if [ -f "$app_dir/.installed_commit" ]; then
    cat "$app_dir/.installed_commit" 2>/dev/null || echo "unknown"
  else
    local repo_dir
    repo_dir=$(get_vpsforge_repo_dir)
    if [ -d "$repo_dir/.git" ]; then
      git -C "$repo_dir" rev-parse --short HEAD 2>/dev/null || echo "unknown"
    else
      echo "unknown"
    fi
  fi
}

# Auto-sync active /opt/vpsforge from /opt/vpsforge/repo if repo was updated manually
sync_active_from_repo() {
  local app_dir repo_dir repo_commit installed_commit
  app_dir=$(get_vpsforge_app_dir)
  repo_dir=$(get_vpsforge_repo_dir)

  # Only sync if repo is a separate directory inside app_dir
  [ "$repo_dir" != "$app_dir" ] || return 0
  [ -d "$repo_dir/.git" ] || return 0

  repo_commit=$(git -C "$repo_dir" rev-parse --short HEAD 2>/dev/null || true)
  installed_commit=$(get_active_installed_commit)

  if [ -n "$repo_commit" ] && [ "$repo_commit" != "$installed_commit" ]; then
    echo "Detected updated repository ($installed_commit -> $repo_commit). Synchronizing active installation..." >&2
    _apply_staged_code_sync "$app_dir" "$repo_dir" "$repo_commit" >/dev/null 2>&1 || true
  fi
}

# Internal helper: Atomically copy code from repo to active dir and purge obsolete files
_apply_staged_code_sync() {
  local app_dir="$1" repo_dir="$2" target_commit="$3"
  local staging_lib="$app_dir/.lib_staging_$$"
  local staging_app="$app_dir/.vpsforge.sh_staging_$$"

  rm -rf "$staging_lib" "$staging_app" 2>/dev/null || true

  # 1. Stage new files
  if [ -d "$repo_dir/lib" ]; then
    cp -r "$repo_dir/lib" "$staging_lib" || { rm -rf "$staging_lib"; return 1; }
    find "$staging_lib" -type f -name "*.sh" -exec chmod 755 {} + 2>/dev/null || true
  else
    return 1
  fi

  if [ -f "$repo_dir/vpsforge.sh" ]; then
    cp "$repo_dir/vpsforge.sh" "$staging_app" || { rm -rf "$staging_lib" "$staging_app"; return 1; }
    chmod 755 "$staging_app"
  else
    rm -rf "$staging_lib"
    return 1
  fi

  # 2. Backup current active files for rollback safety
  if [ -d "$app_dir/lib" ]; then
    rm -rf "$app_dir/lib.backup" 2>/dev/null || true
    cp -r "$app_dir/lib" "$app_dir/lib.backup" 2>/dev/null || true
  fi
  if [ -f "$app_dir/vpsforge.sh" ]; then
    cp "$app_dir/vpsforge.sh" "$app_dir/vpsforge.sh.backup" 2>/dev/null || true
  fi

  # 3. Atomically replace active code (this purges deleted/obsolete files)
  rm -rf "$app_dir/lib"
  mv "$staging_lib" "$app_dir/lib"
  mv -f "$staging_app" "$app_dir/vpsforge.sh"

  # 4. Save tracking commit metadata
  echo "$target_commit" > "$app_dir/.installed_commit"
  if [ -f "$repo_dir/vpsforge.sh" ]; then
    local ver
    ver=$(sed -n 's/^VPSFORGE_VERSION="\(v[0-9][0-9.]*\)"/\1/p' "$repo_dir/vpsforge.sh" 2>/dev/null | head -n1)
    [ -n "$ver" ] && echo "$ver" > "$app_dir/.installed_version"
  fi

  # 5. Integrity Verification
  if ! diff -r -q "$app_dir/lib" "$repo_dir/lib" >/dev/null 2>&1; then
    echo "ERROR: Active installation verification failed after sync. Rolling back..." >&2
    if [ -d "$app_dir/lib.backup" ]; then
      rm -rf "$app_dir/lib"
      mv "$app_dir/lib.backup" "$app_dir/lib"
    fi
    if [ -f "$app_dir/vpsforge.sh.backup" ]; then
      mv -f "$app_dir/vpsforge.sh.backup" "$app_dir/vpsforge.sh"
    fi
    return 1
  fi

  rm -rf "$app_dir"/lib.backup* "$app_dir"/vpsforge.sh.backup* "$app_dir"/raw_incus.txt "$app_dir"/ubuntu_images_cache.txt 2>/dev/null || true
  return 0
}

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
  unpushed=$(git -C "$repo_dir" log @{u}.. 2>/dev/null | grep '^commit ' | wc -l || echo 0)
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
  if [ -f "$app_dir/lib/core/setup/ensure_setup.sh" ]; then
    # shellcheck disable=SC1090
    source "$app_dir/lib/core/setup/ensure_setup.sh"
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

vpsforge_list_versions() {
  local repo_dir
  repo_dir=$(get_vpsforge_repo_dir)

  if [ ! -d "$repo_dir/.git" ]; then
    echo "Repository not initialized at $repo_dir. Run 'vpsforge update' to initialize."
    return 1
  fi

  echo "Fetching latest version list..."
  git -C "$repo_dir" fetch --tags --prune >/dev/null 2>&1 || true

  local -a tags
  mapfile -t tags < <(git -C "$repo_dir" tag --sort=-version:refname 2>/dev/null || true)

  echo "Available VPSForge releases:"
  if [ "${#tags[@]}" -eq 0 ]; then
    echo "  (No release tags found. Main branch is available: 'latest')"
  else
    local t current_ver
    current_ver=$(sed -n 's/^VPSFORGE_VERSION="\(v[0-9][0-9.]*\)"/\1/p' "$(get_vpsforge_app_dir)/vpsforge.sh" 2>/dev/null | head -n1)
    for t in "${tags[@]}"; do
      if [ "$t" = "$current_ver" ]; then
        echo "  * $t (currently active)"
      else
        echo "    $t"
      fi
    done
  fi
  echo
  echo "Usage to switch version:"
  echo "  vpsforge update latest"
  echo "  vpsforge update <version_tag>"
}

vpsforge_check_update_status() {
  local app_dir repo_dir active_commit repo_commit remote_commit
  app_dir=$(get_vpsforge_app_dir)
  repo_dir=$(get_vpsforge_repo_dir)

  echo "Checking VPSForge synchronization and update status..."
  active_commit=$(get_active_installed_commit)

  if [ ! -d "$repo_dir/.git" ]; then
    echo "Repository: Not initialized ($repo_dir)"
    echo "Status:     Needs initialization via 'vpsforge update'"
    return 1
  fi

  git -C "$repo_dir" fetch origin main --quiet 2>/dev/null || true
  repo_commit=$(git -C "$repo_dir" rev-parse --short HEAD 2>/dev/null || echo "unknown")
  remote_commit=$(git -C "$repo_dir" rev-parse --short origin/main 2>/dev/null || echo "unknown")

  echo "Active installation commit: $active_commit ($app_dir)"
  echo "Local repository commit:    $repo_commit ($repo_dir)"
  echo "Remote origin/main commit:  $remote_commit"

  if [ "$active_commit" = "$remote_commit" ] && [ "$repo_commit" = "$remote_commit" ]; then
    echo "Status: Up to date & Synced with origin/main."
  elif [ "$active_commit" != "$repo_commit" ]; then
    echo "Status: OUT OF SYNC (Active installation is behind local repository). Run 'vpsforge update' to sync."
  else
    echo "Status: UPDATE AVAILABLE (Remote has newer commits). Run 'vpsforge update' to upgrade."
  fi
}

vpsforge_print_status() {
  vpsforge_check_update_status
}

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
  echo "Fetching fresh repository from $repo_url..."
  rm -rf "$repo_dir"
  if ! git clone "$repo_url" "$repo_dir"; then
    echo "ERROR: Failed to clone fresh repository from $repo_url." >&2
    return 1
  fi

  # 3. Synchronize cleanly to active installation
  short_sha=$(git -C "$repo_dir" rev-parse --short HEAD 2>/dev/null || echo "unknown")
  echo "Synchronizing fresh code (commit $short_sha)..."
  if ! _apply_staged_code_sync "$app_dir" "$repo_dir" "$short_sha"; then
    echo "ERROR: Clean synchronization failed." >&2
    return 1
  fi

  # 4. Refresh symlinks and wrappers
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
  chmod 755 /usr/local/bin/vpsforge-update

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
