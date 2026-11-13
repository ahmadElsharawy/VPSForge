#!/bin/bash
# Export a VPS to a file (zstd compressed: several times smaller, less real disk used).
# Leftover temporary backups are cleared first, and the real Incus error is shown on failure.
#   _export_instance <vps_name> <file>
_export_instance() {
  local name="${1:?vps}" file="${2:?file}" err reason
  local -a compress_args=()
  delete_internal_backups "$name"
  incus export --help 2>&1 | grep -q -- '--compression' && compress_args=(--compression zstd)

  err=$(mktemp)
  if incus export "$name" "$file" "${compress_args[@]}" 2>"$err"; then
    rm -f "$err"
    # A file that cannot be read back is useless: fail so the guard deletes it.
    if command -v zstd >/dev/null 2>&1 && ! tar -tf "$file" >/dev/null 2>&1; then
      echo "ERROR: the backup file came out damaged, so it was deleted"
      return 1
    fi
    return 0
  fi
  reason=$(tr '\r' '\n' < "$err" | grep -v '^ *$' | grep -vi 'backing up\|exporting' | tail -n 1)
  # A full VPS disk stops the export (Incus writes a small file inside the VPS first). Space just
  # freed inside the VPS comes back slowly on ZFS, so wait until its free space stops growing, then try once more.
  # The VPS's disk limit is never raised for this: ZFS cannot lower it back once the space is used.
  if printf '%s' "$reason" | grep -qi 'quota'; then
    _wait_vps_space_settled "$name"
    rm -f "$file"
    if incus export "$name" "$file" "${compress_args[@]}" 2>"$err"; then
      rm -f "$err"
      return 0
    fi
    rm -f "$err"
    echo "ERROR: the disk of $name is full, so it cannot be backed up. Free some space inside the VPS, then try again."
    return 1
  fi
  rm -f "$err"
  echo "ERROR: incus could not export $name${reason:+: $reason}"
  return 1
}
