#!/bin/bash
# Check a name typed in the Add wizard right away: valid for Incus, not used by
# an existing VPS, and not already picked earlier in the same wizard.
#   add_name_is_usable <name> [names already picked...]
add_name_is_usable() {
  local name="${1:-}" picked
  shift
  if ! is_valid_vps_name "$name"; then
    echo "Invalid name '$name'. Use letters, digits and dashes only, starting with a letter."
    return 1
  fi
  if incus info "$name" >/dev/null 2>&1; then
    echo "A VPS named '$name' already exists. Choose another name."
    return 1
  fi
  for picked in "$@"; do
    if [ "$picked" = "$name" ]; then
      echo "You already used the name '$name' for another new VPS."
      return 1
    fi
  done
  return 0
}
