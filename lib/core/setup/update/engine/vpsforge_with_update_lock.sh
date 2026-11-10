#!/bin/bash
# Run an update command while holding the update lock, so two updates (two terminals, or the
# menu and the CLI at the same time) can never replace the code at the same moment.
# A second update waits up to 2 minutes, then gives up with a message. After a real update in a
# terminal, VPSForge is reloaded with the new code (outside the lock, so the lock is let go).
#   vpsforge_with_update_lock <command> [args...]
vpsforge_with_update_lock() {
  local lock="/run/vpsforge-update.lock" done_file rc
  if ! command -v flock >/dev/null 2>&1; then
    "$@"
    return $?
  fi
  done_file=$(mktemp /run/vpsforge-updated-XXXXXX) && rm -f "$done_file"
  (
    if ! flock -w 120 9; then
      echo "Another VPSForge update is running. Try again in a few minutes." >&2
      exit 1
    fi
    VPSFORGE_UPDATE_DONE_FILE="$done_file" "$@"
  ) 9>"$lock"
  rc=$?
  if [ -f "$done_file" ]; then
    rm -f "$done_file"
    if [ -t 0 ] && [ -n "${VPSFORGE_VERSION:-}" ]; then
      echo "Reloading VPSForge in current session..."
      sleep 1
      exec "$(get_vpsforge_app_dir)/vpsforge.sh"
    fi
  fi
  return "$rc"
}
