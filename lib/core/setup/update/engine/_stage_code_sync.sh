#!/bin/bash
# Stage new lib and vpsforge.sh files from repository into staging paths.
#   _stage_code_sync <repo_dir> <staging_lib> <staging_app>
_stage_code_sync() {
  local repo_dir="$1" staging_lib="$2" staging_app="$3"
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
  return 0
}
