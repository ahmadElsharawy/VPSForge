#!/bin/bash
# Simulate apt purge to ensure uninstallation does not remove later-installed dependencies.
#   _uninstall_check_package_dependencies <package_list...>
_uninstall_check_package_dependencies() {
  local -a extras=()
  local removed
  while read -r removed; do
    [ -n "$removed" ] || continue
    printf '%s\n' "$@" | grep -qxF "$removed" || extras+=("$removed")
  done < <(apt-get -s purge "$@" 2>/dev/null | awk '/^(Remv|Purg) /{print $2}')

  if [ "${#extras[@]}" -gt 0 ]; then
    echo "  Not removed: other packages you installed later depend on them (${extras[*]})."
    return 1
  fi
  return 0
}
