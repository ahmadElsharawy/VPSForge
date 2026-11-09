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
  rm -f "$err"
  echo "ERROR: incus could not export $name${reason:+: $reason}"
  return 1
}
