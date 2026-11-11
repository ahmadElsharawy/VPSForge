#!/bin/bash
# Verifies that the installed VPSForge binary reports the expected target version.
verify_installed_version() {
  local app="$1" target="$2" installed="" attempt

  for attempt in $(seq 1 10); do
    installed=$("$app" --version 2>/dev/null | extract_version_from_text)
    [ "$installed" = "$target" ] && return 0
    sleep 1
  done

  installed=$(sed -n 's/^VPSFORGE_VERSION="\(v[0-9][0-9.]*\)"/\1/p' "$app" 2>/dev/null | head -n1)
  [ "$installed" = "$target" ]
}
