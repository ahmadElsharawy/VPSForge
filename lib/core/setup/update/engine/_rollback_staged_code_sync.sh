#!/bin/bash
# Restore lib and vpsforge.sh from backup in app_dir after sync failure.
#   _rollback_staged_code_sync <app_dir>
_rollback_staged_code_sync() {
  local app_dir="$1"
  if [ -d "$app_dir/lib.backup" ]; then
    rm -rf "${app_dir:?}/lib"
    mv "$app_dir/lib.backup" "$app_dir/lib"
  fi
  if [ -f "$app_dir/vpsforge.sh.backup" ]; then
    mv -f "$app_dir/vpsforge.sh.backup" "$app_dir/vpsforge.sh"
  fi
}
