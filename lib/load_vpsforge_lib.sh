#!/bin/bash
# Loads every VPSForge library file (one function per file) from <lib_dir>.
# Variables first (constants.sh and *_globals.sh), then every function file.
# File location does not matter, so folders can be reorganized freely.

# Sources all library scripts (globals and functions) from the specified directory.
load_vpsforge_lib() {
  local lib_dir="${1:?usage: load_vpsforge_lib <lib_dir>}" file

  while read -r file; do
    # shellcheck disable=SC1090
    source "$file"
  done < <(find "$lib_dir" -type f \( -name 'constants.sh' -o -name '*_globals.sh' \) | sort)

  while read -r file; do
    # shellcheck disable=SC1090
    source "$file"
  done < <(find "$lib_dir" -type f -name '*.sh' ! -name 'load_vpsforge_lib.sh' ! -name 'constants.sh' ! -name '*_globals.sh' | sort)
}
