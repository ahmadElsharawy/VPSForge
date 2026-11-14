#!/bin/bash
# Make sure the incus command really exists (a stale dpkg state can mark it installed with no binary); warn loudly if not.
ensure_incus_usable() {
  if ! command -v incus >/dev/null 2>&1 && dpkg -l incus-client 2>/dev/null | grep -q '^ii'; then
    wait_for_apt_lock
    apt-get install -y --reinstall incus-client incus >/dev/null 2>&1 || true
  fi
  if ! command -v incus >/dev/null 2>&1; then
    echo "WARNING: the 'incus' command is not working - storage and VPS features will NOT work until Incus is fixed." >&2
  fi
  return 0
}
