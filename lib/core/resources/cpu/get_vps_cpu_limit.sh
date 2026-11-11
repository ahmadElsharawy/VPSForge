#!/bin/bash
# Returns configured CPU limit for a VPS, or total host CPU count if unlimited.
get_vps_cpu_limit() {
  local vps_name="$1" configured
  configured=$(incus config get "$vps_name" limits.cpu 2>/dev/null || true)
  if [ -n "$configured" ]; then
    echo "$configured"
  else
    get_host_cpu_count
  fi
}
