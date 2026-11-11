#!/bin/bash
# Resolves a selection token (1-based index, numeric suffix, or container name) to a VPS name.
_resolve_vps_token() {
  local token="$1" idx
  if [[ "$token" =~ ^[0-9]+$ ]] && [ "$token" -ge 1 ] && [ "$token" -le "${#AVAILABLE_VPS_LIST[@]}" ]; then
    idx=$((token - 1))
    echo "${AVAILABLE_VPS_LIST[$idx]}"
  elif [[ "$token" =~ ^[0-9]+$ ]]; then
    echo "${VPS_PREFIX}${token}"
  else
    echo "$token"
  fi
}
