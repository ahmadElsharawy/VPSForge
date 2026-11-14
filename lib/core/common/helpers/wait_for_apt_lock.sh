#!/bin/bash
# Wait (up to ~300s) until nothing holds the apt/dpkg locks, then repair any half-configured packages. Always returns 0.
wait_for_apt_lock() {
  local tries=0 locks="/var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock"
  if command -v fuser >/dev/null 2>&1; then
    # shellcheck disable=SC2086
    while fuser $locks >/dev/null 2>&1; do
      tries=$((tries + 1))
      [ "$tries" -ge 100 ] && break
      [ "$tries" -eq 1 ] && echo "Waiting for another apt/dpkg process (Ubuntu automatic updates) to finish..." >&2
      sleep 3
    done
  fi
  dpkg --configure -a >/dev/null 2>&1 || true
  return 0
}
