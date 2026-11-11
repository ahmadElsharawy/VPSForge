#!/bin/bash
# Remove half-written export files and Incus's temporary backups, but never while an export is running.
clean_stale_temp_backups() {
  pgrep -x incus -a 2>/dev/null | grep -q ' export ' && return 0
  local tmp_dir="/opt/vpsforge-backups/.tmp"
  if [ -d "$tmp_dir" ]; then
    local file_path
    for file_path in "$tmp_dir"/*; do
      [ -f "$file_path" ] || continue
      # a file touched in the last 10 minutes may be a finished export that another session is about to move
      if [ -n "$(find "$file_path" -mmin +10 2>/dev/null)" ] && ! fuser "$file_path" >/dev/null 2>&1; then
        rm -f "$file_path"
      fi
    done
  fi

  _clean_incus_internal_backups
}
