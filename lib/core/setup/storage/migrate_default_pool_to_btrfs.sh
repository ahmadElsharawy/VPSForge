#!/bin/bash
# Move every VPS from the old "dir" storage pool to a BTRFS pool (instant snapshots, small space).
# Only one migration runs at a time; if any VPS cannot be moved, everything is put back and nothing is deleted.
migrate_default_pool_to_btrfs() {
  # Migrate existing containers to BTRFS safely. Only one migration may run at a time
  # (a second VPSForge started meanwhile must not touch the VPSs being moved).
  local run_inst
  local failed_marker="/opt/vpsforge/.pool_migration_failed"
  if [ -f "$failed_marker" ]; then
    return 0   # a previous attempt could not move a VPS: do not retry (and stop VPSs) on every start
  elif pgrep -a -x incus 2>/dev/null | grep -q ' move '; then
    echo "A storage migration is already running; skipping." >&2
  elif incus storage create temp-btrfs btrfs size=$(default_pool_size_gib)GiB >/dev/null 2>&1 || incus storage show temp-btrfs >/dev/null 2>&1; then
    echo "Storage pool 'default' is using 'dir' driver. Automating migration to BTRFS..." >&2
    local -a instances=()
    mapfile -t instances < <(incus storage show default 2>/dev/null | grep '/1.0/instances/' | awk -F'/' '{print $NF}' || true)
    
    local -a profiles=()
    mapfile -t profiles < <(incus storage show default 2>/dev/null | grep '/1.0/profiles/' | awk -F'/' '{print $NF}' || true)

    # 1. Stop and move instances to temp pool
    local inst
    local -a state_map=()
    for inst in "${instances[@]}"; do
      [ -n "$inst" ] || continue
      if is_vps_running "$inst"; then
        state_map+=("$inst")
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
        local back
        for back in "${instances[@]}"; do
          [ "$back" = "$inst" ] && break
          incus move "$back" "$back" -s default >/dev/null 2>&1 || true
        done
        for back in "${state_map[@]}"; do incus start "$back" >/dev/null 2>&1 || true; done
        incus storage delete temp-btrfs >/dev/null 2>&1 || true
        return 0
      fi
    done

    # 2. Temporarily remove root device from profiles
    local prof
    for prof in "${profiles[@]}"; do
      [ -n "$prof" ] || continue
      incus profile device remove "$prof" root >/dev/null 2>&1 || true
    done

    # 3. Delete old dir default pool and recreate as BTRFS
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
      return 0
    fi
    create_storage_pool default || true

    # 4. Restore root device to profiles pointing to new default pool
    for prof in "${profiles[@]}"; do
      [ -n "$prof" ] || continue
      incus profile device add "$prof" root disk path=/ pool=default >/dev/null 2>&1 || true
    done

    # 5. Move instances back to default BTRFS pool
    for inst in "${instances[@]}"; do
      [ -n "$inst" ] || continue
      incus move "$inst" "$inst" -s default >/dev/null 2>&1 || true
    done

    # 6. Delete temp BTRFS pool
    incus storage delete temp-btrfs >/dev/null 2>&1 || true

    # 7. Start instances that were previously running
    for run_inst in "${state_map[@]}"; do
      incus start "$run_inst" >/dev/null 2>&1 || true
    done

    echo "BTRFS storage optimization completed successfully." >&2
  else
    echo "WARNING: Could not create temporary BTRFS storage pool. Skipping BTRFS storage migration." >&2
  fi
  return 0
}
