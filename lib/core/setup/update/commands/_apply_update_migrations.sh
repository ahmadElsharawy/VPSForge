#!/bin/bash
# Source updated libraries and run post-update migrations.
#   _apply_update_migrations <app_dir>
_apply_update_migrations() {
  local app_dir="$1"
  if [ -f "$app_dir/lib/load_vpsforge_lib.sh" ]; then
    # shellcheck disable=SC1091
    source "$app_dir/lib/load_vpsforge_lib.sh"
    load_vpsforge_lib "$app_dir/lib"
    cleanup_legacy_dockerenv_markers 2>/dev/null || true
  fi
}
