#!/bin/bash
# Stop and move instances from the default pool to the temporary pool, saving migration state.
#   _move_instances_to_temp_pool <state_file> <failed_marker> [instance1 instance2 ...]
_move_instances_to_temp_pool() {
  local state_file="${1:?state_file}" failed_marker="${2:?failed_marker}"
  shift 2
  local -a instances=("$@")
  local inst back
  local -a profiles=() state_map=()

  mapfile -t profiles < <(incus storage show default 2>/dev/null | grep '/1.0/profiles/' | awk -F'/' '{print $NF}' || true)

  for inst in "${instances[@]}"; do
    [ -n "$inst" ] || continue
    is_vps_running "$inst" && state_map+=("$inst")
  done

  { printf 'I %s\n' "${instances[@]}"; printf 'P %s\n' "${profiles[@]}"; printf 'R %s\n' "${state_map[@]}"; } > "$state_file"

  for inst in "${instances[@]}"; do
    [ -n "$inst" ] || continue
    if is_vps_running "$inst"; then
      # wait for the real stop; if the stop command itself failed there is nothing to wait for
      if incus stop "$inst" --force >/dev/null 2>&1; then
        while is_vps_running "$inst"; do
          sleep 1
        done
      fi
    fi
    if ! incus move "$inst" "$inst" -s "$POOL_MIGRATION_TEMP" >/dev/null 2>&1; then
      echo "WARNING: could not move '$inst' to the temporary pool. Storage migration cancelled; nothing was deleted." >&2
      touch "$failed_marker"
      for back in "${instances[@]}"; do
        [ "$back" = "$inst" ] && break
        incus move "$back" "$back" -s default >/dev/null 2>&1 || true
      done
      for back in "${state_map[@]}"; do incus start "$back" >/dev/null 2>&1 || true; done
      incus storage delete "$POOL_MIGRATION_TEMP" >/dev/null 2>&1 || true
      rm -f "$state_file"
      return 1
    fi
  done
  return 0
}
