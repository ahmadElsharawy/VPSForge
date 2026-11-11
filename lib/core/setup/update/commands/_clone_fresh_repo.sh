#!/bin/bash
# Clone a fresh copy of the VPSForge git repository into the target directory.
#   _clone_fresh_repo <repo_url> <repo_dir> <app_dir>
_clone_fresh_repo() {
  local repo_url="${1:?repo_url}" repo_dir="${2:?repo_dir}" app_dir="${3:?app_dir}"
  echo "Fetching fresh repository from $repo_url..."
  if [ "$(readlink -f "$repo_dir")" = "$(readlink -f "$app_dir")" ]; then
    echo "ERROR: the repository folder is the installation folder itself; refusing to delete it." >&2
    return 1
  fi
  local fresh_dir="${repo_dir}.new"
  rm -rf "$fresh_dir"
  if ! git clone "$repo_url" "$fresh_dir"; then
    echo "ERROR: Failed to clone fresh repository from $repo_url. The current copy was kept." >&2
    rm -rf "$fresh_dir"
    return 1
  fi
  rm -rf "$repo_dir"
  mv "$fresh_dir" "$repo_dir"
}
