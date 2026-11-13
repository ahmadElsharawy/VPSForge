#!/bin/bash
# Delete the old default pool and create the new one (create_storage_pool), or roll back if deletion fails.
#   _recreate_default_pool <state_file> <failed_marker>
_recreate_default_pool() {
  local state_file="${1:?state_file}" failed_marker="${2:?failed_marker}"
  local kind name prof inst run_inst
  local -a instances=() profiles=() state_map=()

  while read -r kind name; do
    [ -n "$name" ] || continue
    case "$kind" in
      I) instances+=("$name");;
      P) profiles+=("$name");;
      R) state_map+=("$name");;
    esac
  done < "$state_file"

  # 2. Temporarily remove the root device from the profiles
  for prof in "${profiles[@]}"; do
    [ -n "$prof" ] || continue
    incus profile device remove "$prof" root >/dev/null 2>&1 || true
  done

  # 3. Delete the old pool and recreate it with the better driver
  incus storage delete default >/dev/null 2>&1 || true
  if incus storage show default >/dev/null 2>&1; then
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
    incus storage delete "$POOL_MIGRATION_TEMP" >/dev/null 2>&1 || true
    for run_inst in "${state_map[@]}"; do incus start "$run_inst" >/dev/null 2>&1 || true; done
    touch "$failed_marker"
    rm -f "$state_file"
    return 1
  fi
  create_storage_pool default || return 1
  return 0
}
