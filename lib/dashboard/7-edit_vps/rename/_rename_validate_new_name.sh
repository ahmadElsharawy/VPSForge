#!/bin/bash
# Validates VPS container name format and verifies uniqueness.
_rename_validate_new_name() {
  local new_name="$1"
  if ! is_valid_vps_name "$new_name"; then
    echo "ERROR: Invalid VPS name '$new_name'. Use letters, digits and dashes only (no dots, underscores or spaces; not only digits; no dash at the start or end)."
    return 1
  fi

  if incus list -c n --format csv 2>/dev/null | grep -Fxq "$new_name"; then
    echo "ERROR: A VPS with name '$new_name' already exists."
    return 1
  fi
  return 0
}
