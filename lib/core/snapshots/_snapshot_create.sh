#!/bin/bash
# Take one snapshot of a VPS.
#   _snapshot_create <vps_name> <snapshot_name>
_snapshot_create() {
  incus snapshot create "${1:?vps}" "${2:?snapshot}" || { echo "ERROR: incus could not create the snapshot."; return 1; }
}
