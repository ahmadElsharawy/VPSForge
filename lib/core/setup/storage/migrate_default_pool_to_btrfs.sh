#!/bin/bash
# Move every VPS from the old "dir" storage pool to a BTRFS pool (instant snapshots, small space).
# Safe by design:
#   - only VPSForge's own VPSs are moved: if the pool also holds anything else, nothing is touched;
#   - only one migration runs at a time;
#   - if a VPS cannot be moved, everything is put back and nothing is deleted;
#   - if the migration was stopped half-way (power loss, kill), the next start finishes it.
migrate_default_pool_to_btrfs() {
  local run_inst inst prof back
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

  local -a instances=() profiles=() foreign=()
  mapfile -t instances < <(incus storage show default 2>/dev/null | grep -E '/1.0/instances/[^/]+$' | awk -F'/' '{print $NF}' || true)
  mapfile -t profiles < <(incus storage show default 2>/dev/null | grep '/1.0/profiles/' | awk -F'/' '{print $NF}' || true)
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

  # 1. Stop and move instances to the temporary pool (the list is saved so a stopped migration can finish)
  local -a state_map=()
  for inst in "${instances[@]}"; do
    [ -n "$inst" ] || continue
    is_vps_running "$inst" && state_map+=("$inst")
  done
  { printf 'I %s\n' "${instances[@]}"; printf 'P %s\n' "${profiles[@]}"; printf 'R %s\n' "${state_map[@]}"; } > "$state_file"
  for inst in "${instances[@]}"; do
    [ -n "$inst" ] || continue
    if is_vps_running "$inst"; then
      incus stop "$inst" --force >/dev/null 2>&1 || true
      local wait_count=0
      while is_vps_running "$inst" && [ $wait_count -lt 15 ]; do
        sleep 1
        wait_count=$((wait_count + 1))
      done
    fi
    if ! incus move "$inst" "$inst" -s temp-btrfs >/dev/null 2>&1; then
      echo "WARNING: could not move '$inst' to the temporary pool. Storage migration cancelled; nothing was deleted." >&2
      touch "$failed_marker"
      for back in "${instances[@]}"; do
        [ "$back" = "$inst" ] && break
        incus move "$back" "$back" -s default >/dev/null 2>&1 || true
      done
      for back in "${state_map[@]}"; do incus start "$back" >/dev/null 2>&1 || true; done
      incus storage delete temp-btrfs >/dev/null 2>&1 || true
      rm -f "$state_file"
      return 0
    fi
  done

  # 2. Temporarily remove the root device from the profiles
  for prof in "${profiles[@]}"; do
    [ -n "$prof" ] || continue
    incus profile device remove "$prof" root >/dev/null 2>&1 || true
  done

  # 3. Delete the old dir pool and recreate it as BTRFS
  incus storage delete default >/dev/null 2>&1 || true
  if incus storage show default 2>/dev/null | grep -q 'driver: dir'; then
    # The old pool could not be deleted (it holds something else): put everything back and stop trying.
    echo "WARNING: the old storage pool could not be replaced. Everything was put back; migration cancelled." >&2
    for prof in "${profiles[@]}"; do
      [ -n "$prof" ] || continue
      incus profile device add "$prof" root disk path=/ pool=default >/dev/null 2>&1 || true
    done
    for inst in "${instances[@]}"; do
      [ -n "$inst" ] || continue
      incus move "$inst" "$inst" -s default >/dev/null 2>&1 || true
    done
    incus storage delete temp-btrfs >/dev/null 2>&1 || true
    for run_inst in "${state_map[@]}"; do incus start "$run_inst" >/dev/null 2>&1 || true; done
    touch "$failed_marker"
    rm -f "$state_file"
    return 0
  fi
  create_storage_pool default || true

  # 4-7. Profiles back, VPSs back, temporary pool removed, VPSs started again
  _resume_pool_migration "$state_file"
  return 0
}
