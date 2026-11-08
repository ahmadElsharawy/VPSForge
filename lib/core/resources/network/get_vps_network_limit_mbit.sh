#!/bin/bash
get_vps_network_limit_mbit() {
  local raw
  raw=$(incus config device get "$1" eth0 limits.ingress 2>/dev/null || true)
  [[ "$raw" =~ ^([0-9]+)[Mm]bit$ ]] && echo "${BASH_REMATCH[1]}" || true
}
