#!/bin/bash
# Return the active installation directory of VPSForge.
get_vpsforge_app_dir() {
  if [ -n "${VPSFORGE_SCRIPT_DIR:-}" ] && [ -d "$VPSFORGE_SCRIPT_DIR" ]; then
    echo "$VPSFORGE_SCRIPT_DIR"
  elif [ -d "/opt/vpsforge" ]; then
    echo "/opt/vpsforge"
  else
    cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../.." && pwd
  fi
}
