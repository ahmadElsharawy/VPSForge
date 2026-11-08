#!/bin/bash
# Export a VPS to a file (zstd compressed: several times smaller, less real disk used).
#   _export_instance <vps_name> <file>
_export_instance() {
  local name="${1:?vps}" file="${2:?file}"
  local -a compress_args=()
  incus export --help 2>&1 | grep -q -- '--compression' && compress_args=(--compression zstd)
  incus export "$name" "$file" "${compress_args[@]}" || { echo "ERROR: incus could not export $name (see message above)."; return 1; }
}
