#!/bin/bash
# Take one snapshot of a VPS.
#   _snapshot_create <vps_name> <snapshot_name>
_snapshot_create() {
  local vps="${1:?vps}" snap="${2:?snapshot}"
  incus snapshot create "$vps" "$snap" || { echo "ERROR: incus could not create the snapshot."; return 1; }
  # A snapshot that cannot be read back is useless: fail so the guard deletes it.
  if ! incus snapshot show "$vps" "$snap" >/dev/null 2>&1; then
    echo "ERROR: the snapshot came out damaged, so it was deleted."
    return 1
  fi
}
