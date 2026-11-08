#!/bin/bash
get_vps_cpu_limit() {
  local configured
  configured=$(incus config get "$1" limits.cpu 2>/dev/null || true)
  if [ -n "$configured" ]; then
    echo "$configured"
  else
    get_host_cpu_count
  fi
}
