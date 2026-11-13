#!/bin/bash
# Wait until the free space seen inside a VPS stops growing (space just freed comes back slowly on ZFS).
# Checks every 2 seconds; returns at once if the VPS cannot report its free space.
#   _wait_vps_space_settled <vps_name>
_wait_vps_space_settled() {
  local name="${1:?vps}" before after
  before=$(incus exec "$name" -- df -B1 --output=avail / 2>/dev/null | tail -n 1 | tr -d ' ')
  while [[ "$before" =~ ^[0-9]+$ ]]; do
    sleep 2
    after=$(incus exec "$name" -- df -B1 --output=avail / 2>/dev/null | tail -n 1 | tr -d ' ')
    [[ "$after" =~ ^[0-9]+$ ]] && [ "$after" -gt "$before" ] || return 0
    before="$after"
  done
  return 0
}
