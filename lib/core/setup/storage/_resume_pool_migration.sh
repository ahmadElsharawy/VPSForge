#!/bin/bash
# Last part of the BTRFS migration, also used to finish one that was stopped half-way:
# the new default pool is made if missing, profiles get their root disk again, every VPS is
# moved back from temp-btrfs, the temporary pool is removed and the VPSs that ran are started.
# The temporary pool is kept (and a warning shown) if a VPS could not be moved back.
#   _resume_pool_migration <state_file>
_resume_pool_migration() {
  local state_file="${1:?state file}" kind name ok=1
  local -a instances=() profiles=() running=()
  while read -r kind name; do
    [ -n "$name" ] || continue
    case "$kind" in
      I) instances+=("$name");;
      P) profiles+=("$name");;
      R) running+=("$name");;
    esac
  done < "$state_file"
  incus storage show default >/dev/null 2>&1 || create_storage_pool default || true
  for name in "${profiles[@]}"; do
    incus profile device add "$name" root disk path=/ pool=default >/dev/null 2>&1 || true
  done
  for name in "${instances[@]}"; do
    incus info "$name" >/dev/null 2>&1 || continue
    incus config show "$name" --expanded 2>/dev/null | grep -q 'pool: temp-btrfs' || continue
    if ! incus move "$name" "$name" -s default >/dev/null 2>&1; then
      echo "WARNING: '$name' could not be moved back to the default pool; it keeps working from 'temp-btrfs'." >&2
      ok=0
    fi
  done
  [ "$ok" -eq 1 ] && incus storage delete temp-btrfs >/dev/null 2>&1
  for name in "${running[@]}"; do
    incus start "$name" >/dev/null 2>&1 || true
  done
  rm -f "$state_file"
  [ "$ok" -eq 1 ] && echo "BTRFS storage optimization completed successfully." >&2
  return 0
}
