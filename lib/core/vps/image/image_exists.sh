#!/bin/bash
image_exists() {
  local img="$1"
  [ -n "$img" ] || return 1
  if incus image info "$img" >/dev/null 2>&1; then
    return 0
  fi
  local c
  while read -r c; do
    [ -n "$c" ] || continue
    incus image info "$c" >/dev/null 2>&1 && return 0
  done < <(resolve_image_candidates "$img")
  return 1
}
