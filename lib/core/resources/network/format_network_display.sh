#!/bin/bash
format_network_display() {
  local name="$1" limit io
  limit=$(get_vps_network_limit_mbit "$name" 2>/dev/null || true)
  io=$(get_vps_network_io_display "$name" 2>/dev/null || echo "-")
  if [ -n "$limit" ]; then
    echo "${limit}M [${io}]"
  else
    local max
    max=$(get_total_network_mbit 2>/dev/null || echo 10000)
    echo "${max}M [${io}]"
  fi
}
