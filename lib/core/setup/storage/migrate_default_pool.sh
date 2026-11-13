#!/bin/bash
# Move every VPS from the current default storage pool to a new default pool made by
# create_storage_pool (ZFS if the host has it, else BTRFS, else dir).
#   migrate_default_pool <reason>   reason "dir": automatic upgrade of an old dir pool (setup);
#                                   reason "zfs": asked by the owner, the new pool must really be ZFS.
# Safe by design:
#   - only VPSForge's own VPSs are moved: if the pool also holds anything else, nothing is touched;
#   - only one migration runs at a time;
#   - if a VPS cannot be moved, everything is put back and nothing is deleted;
#   - if the migration was stopped half-way (power loss, kill), the next start finishes it.
migrate_default_pool() {
  local reason="${1:-dir}" old_driver new_driver
  local failed_marker="/opt/vpsforge/.pool_migration_failed"
  local state_file="/opt/vpsforge/.pool_migration_running"
  if [ -f "$state_file" ]; then
    if incus storage show "$POOL_MIGRATION_TEMP" >/dev/null 2>&1; then
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
    echo "NOTE: the storage pool also holds containers VPSForge did not create (${foreign[*]}). Storage migration skipped so they are not touched." >&2
    touch "$failed_marker"
    return 0
  fi
  old_driver=$(get_pool_driver default)
  if ! { create_storage_pool "$POOL_MIGRATION_TEMP" || incus storage show "$POOL_MIGRATION_TEMP" >/dev/null 2>&1; }; then
    echo "WARNING: Could not create the temporary storage pool. Skipping the storage migration." >&2
    return 0
  fi
  new_driver=$(get_pool_driver "$POOL_MIGRATION_TEMP")
  if [ "$new_driver" = "dir" ] || { [ "$reason" = "zfs" ] && [ "$new_driver" != "zfs" ]; }; then
    echo "WARNING: a better storage pool (ZFS or BTRFS) cannot be created on this host. Nothing was moved." >&2
    incus storage delete "$POOL_MIGRATION_TEMP" >/dev/null 2>&1 || true
    return 0
  fi
  echo "Storage pool 'default' uses the '$old_driver' driver. Moving every VPS to a better storage pool..." >&2

  _move_instances_to_temp_pool "$state_file" "$failed_marker" "${instances[@]}" || return 0
  _recreate_default_pool "$state_file" "$failed_marker" || return 0
  _resume_pool_migration "$state_file"
  return 0
}
