#!/bin/bash
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
