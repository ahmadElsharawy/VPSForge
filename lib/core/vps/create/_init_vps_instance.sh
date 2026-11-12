#!/bin/bash
# Initialize a container instance from candidate image aliases with fallback.
#   _init_vps_instance <name> <image>
_init_vps_instance() {
  local name="$1" image="$2" cand
  local -a candidates=()
  mapfile -t candidates < <(resolve_image_candidates "$image")

  for cand in "${candidates[@]}"; do
    [ -n "$cand" ] || continue
    echo "Launching $name with image ($cand)..."
    if incus init "$cand" "$name" 2>/dev/null; then
      incus config set "$name" user.vpsforge.image "$cand" || true
      [ "${VPS_TYPE:-full}" = "isolated" ] && incus config set "$name" user.vpsforge.type isolated
      return 0
    fi
  done

  echo "Attempting fallback with detailed output..."
  for cand in "${candidates[@]}"; do
    [ -n "$cand" ] || continue
    if incus init "$cand" "$name"; then
      incus config set "$name" user.vpsforge.image "$cand" || true
      [ "${VPS_TYPE:-full}" = "isolated" ] && incus config set "$name" user.vpsforge.type isolated
      return 0
    fi
  done

  echo "ERROR: Failed to launch $name using image '$image' or available fallback images on Incus." >&2
  return 1
}
