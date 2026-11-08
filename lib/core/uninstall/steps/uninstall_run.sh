#!/bin/bash
# Print a command and run it (only print when UNINSTALL_DRY_RUN=1).
uninstall_run() {
  echo "  - $*"
  [ "${UNINSTALL_DRY_RUN:-0}" = "1" ] && return 0
  "$@" >/dev/null 2>&1 || true
}
