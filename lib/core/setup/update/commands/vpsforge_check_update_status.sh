#!/bin/bash
# Check VPSForge synchronization and update status against the remote repository.
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
