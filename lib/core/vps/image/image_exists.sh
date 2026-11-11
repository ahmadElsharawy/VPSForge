#!/bin/bash
# Check if an Incus container image exists locally or in remote repositories.
image_exists() {
  local img="$1" candidate
  [ -n "$img" ] || return 1
  if incus image info "$img" >/dev/null 2>&1; then
    return 0
  fi
  while read -r candidate; do
    [ -n "$candidate" ] || continue
    incus image info "$candidate" >/dev/null 2>&1 && return 0
  done < <(resolve_image_candidates "$img")
  return 1
}
