#!/bin/bash
# Succeeds when <value> GB is at least 3 and fits in the free space available for <target>.
#   is_valid_disk_value <value> <target>
is_valid_disk_value() {
  local value="${1:-}" target="${2:-}"
  [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge 3 ] && [ "$value" -le "$(get_disk_available_for_vps "$target")" ]
}
