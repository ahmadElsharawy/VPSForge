#!/bin/bash
# Stop Incus from being updated automatically (apt upgrade / unattended-upgrades).
# Use it when this Incus version works for you; remove with incus_unpin.
incus_pin() {
  apt-mark hold incus incus-base incus-client >/dev/null 2>&1 || { echo "ERROR: could not pause Incus updates."; return 1; }
  pref_set incus_pin on
  echo "Incus ($(incus --version 2>/dev/null)) will not be updated automatically."
  echo "(You will not get its security fixes until you run: vpsforge incus unpin)"
}
