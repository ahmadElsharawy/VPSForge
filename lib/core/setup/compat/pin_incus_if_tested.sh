#!/bin/bash
# Right after setup, pause Incus updates while the installed version is the tested one,
# so an update can never silently break VPSForge. Done once, and only if you have not chosen otherwise
# (vpsforge incus unpin turns it off for good).
pin_incus_if_tested() {
  local version major
  [ "$(pref_get incus_pin auto)" = "off" ] && return 0
  apt-mark showhold 2>/dev/null | grep -qx incus && return 0

  version=$(incus --version 2>/dev/null | head -n 1)
  major="${version%%.*}"
  [ "$major" = "$TESTED_INCUS_MAJOR" ] || return 0

  incus_pin >/dev/null 2>&1 || return 0
  echo "Incus $version is the tested version: its updates are paused so they cannot break VPSForge."
  echo "(Allow them again any time with: vpsforge incus unpin)"
}
