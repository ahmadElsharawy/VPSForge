#!/bin/bash
# VPSForge is tested with Incus 6.x (the Ubuntu 24.04 LTS series). When another
# major version is installed (for example after an update from another repository),
# run the quick compatibility self-test and say clearly what to do. Never blocks.
check_incus_version() {
  local version major
  version=$(incus --version 2>/dev/null | head -n 1)
  major="${version%%.*}"
  [[ "$major" =~ ^[0-9]+$ ]] || return 0
  [ "$major" -eq "$TESTED_INCUS_MAJOR" ] && return 0

  echo "NOTICE: Incus $version is installed, but VPSForge is tested with Incus ${TESTED_INCUS_MAJOR}.x. Checking compatibility..."
  if incus_compat_check; then
    echo "        Everything VPSForge needs still works with this Incus."
  else
    echo "        WARNING: this Incus version is NOT compatible with VPSForge."
    echo "           Go back to the tested version: sudo apt install incus=<tested version>, then: vpsforge incus pin"
    echo "           (see which versions exist with: apt-cache madison incus)"
  fi
  return 0
}
