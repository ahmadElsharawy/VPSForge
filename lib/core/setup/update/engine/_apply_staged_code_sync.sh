#!/bin/bash
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
