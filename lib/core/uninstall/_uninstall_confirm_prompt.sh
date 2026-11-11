#!/bin/bash
# Prompt user for confirmation before proceeding with full uninstallation.
#   _uninstall_confirm_prompt <assume_yes>
_uninstall_confirm_prompt() {
  local assume_yes="${1:-0}" answer
  if [ "${UNINSTALL_DRY_RUN:-0}" != "1" ] && [ "$assume_yes" != "1" ]; then
    read -r -p "Type UNINSTALL to permanently remove everything: " answer
    [ "$answer" = "UNINSTALL" ] || { echo "Cancelled."; return 1; }
  fi
  return 0
}
