#!/bin/bash
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
