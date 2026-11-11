#!/bin/bash
# Get the currently installed git commit SHA of VPSForge.
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
