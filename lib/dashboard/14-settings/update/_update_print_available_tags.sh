#!/bin/bash
# Displays a numbered list of available version tags highlighting current version.
_update_print_available_tags() {
  local -a tags=("$@")
  local i
  echo
  echo "Available versions:"
  for i in "${!tags[@]}"; do
    if [ "${tags[$i]}" = "$VPSFORGE_VERSION" ]; then
      echo "$((i+1))) ${tags[$i]} (current)"
    else
      echo "$((i+1))) ${tags[$i]}"
    fi
  done
  echo
}
