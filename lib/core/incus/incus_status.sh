#!/bin/bash
# Show the Incus version, whether its updates are paused, and the tested version.
incus_status() {
  local held="no (it can be updated)"
  apt-mark showhold 2>/dev/null | grep -qx incus && held="yes (updates paused)"
  echo "Incus installed:        $(incus --version 2>/dev/null || echo 'not installed')"
  echo "VPSForge tested with:   Incus ${TESTED_INCUS_MAJOR}.x"
  echo "Incus updates paused:   $held"
}
