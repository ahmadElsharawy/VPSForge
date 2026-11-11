#!/bin/bash
# Auto-sync active /opt/vpsforge from /opt/vpsforge/repo if repo was updated manually.
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
