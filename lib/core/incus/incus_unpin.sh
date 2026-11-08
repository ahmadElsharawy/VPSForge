#!/bin/bash
# Allow Incus to be updated again (and stop pausing it automatically).
incus_unpin() {
  apt-mark unhold incus incus-base incus-client >/dev/null 2>&1 || { echo "ERROR: could not resume Incus updates."; return 1; }
  pref_set incus_pin off
  echo "Incus updates are allowed again. After updating, run: vpsforge selftest"
}
