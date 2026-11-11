#!/bin/bash
# Move every VPS from the old "dir" storage pool to a BTRFS pool (instant snapshots, small space).
# Safe by design:
#   - only VPSForge's own VPSs are moved: if the pool also holds anything else, nothing is touched;
#   - only one migration runs at a time;
#   - if a VPS cannot be moved, everything is put back and nothing is deleted;
#   - if the migration was stopped half-way (power loss, kill), the next start finishes it.
migrate_default_pool_to_btrfs() {
  local failed_marker="/opt/vpsforge/.pool_migration_failed"
  local state_file="/opt/vpsforge/.pool_migration_running"
  if [ -f "$state_file" ]; then
    if incus storage show temp-btrfs >/dev/null 2>&1; then
      _resume_pool_migration "$state_file"
    else
      rm -f "$state_file"   # it had already finished: only the note was left
    fi
    return 0
  fi
  if [ -f "$failed_marker" ]; then
    return 0   # a previous attempt could not move a VPS: do not retry (and stop VPSs) on every start
  elif pgrep -a -x incus 2>/dev/null | grep -q ' move '; then
    echo "A storage migration is already running; skipping." >&2
    return 0
  fi

  local -a instances=() foreign=()
  mapfile -t instances < <(incus storage show default 2>/dev/null | grep -E '/1.0/instances/[^/]+$' | awk -F'/' '{print $NF}' || true)

  # Anything in the pool that VPSForge did not make (no user.vpsforge.* setting) is left alone:
  # the whole migration is skipped rather than stopping someone else's containers.
  mapfile -t foreign < <(incus list --format json 2>/dev/null | python3 -c '
import json, sys
want = set(sys.argv[1:])
for c in json.load(sys.stdin):
    if c["name"] in want and not any(k.startswith("user.vpsforge.") for k in (c.get("config") or {})):
        print(c["name"])
' "${instances[@]}" 2>/dev/null)
  if [ "${#foreign[@]}" -gt 0 ]; then
    echo "NOTE: the storage pool also holds containers VPSForge did not create (${foreign[*]}). BTRFS migration skipped so they are not touched." >&2
    touch "$failed_marker"
    return 0
  fi
  if ! { incus storage create temp-btrfs btrfs size="$(default_pool_size_gib)GiB" >/dev/null 2>&1 || incus storage show temp-btrfs >/dev/null 2>&1; }; then
    echo "WARNING: Could not create temporary BTRFS storage pool. Skipping BTRFS storage migration." >&2
    return 0
  fi
  echo "Storage pool 'default' is using 'dir' driver. Automating migration to BTRFS..." >&2

  _move_instances_to_temp_pool "$state_file" "$failed_marker" "${instances[@]}" || return 0
  _recreate_default_btrfs_pool "$state_file" "$failed_marker" || return 0
  _resume_pool_migration "$state_file"
  return 0
}
