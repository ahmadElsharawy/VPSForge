#!/bin/bash
# Returns configured network ingress limit in Mbit for a VPS, or empty if unlimited.
get_vps_network_limit_mbit() {
  local vps_name="$1" raw
  raw=$(incus config device get "$vps_name" eth0 limits.ingress 2>/dev/null || true)
  [[ "$raw" =~ ^([0-9]+)[Mm]bit$ ]] && echo "${BASH_REMATCH[1]}" || true
}
