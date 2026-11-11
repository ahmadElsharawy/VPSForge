#!/bin/bash
# Formats RAM usage, limit, and host total for table/dashboard display.
format_ram_display() {
  local name="$1" used limit total
  used=$(get_vps_ram_usage_mb "$name")
  limit=$(get_vps_ram_limit_mb "$name")
  total=$(get_host_total_ram_mb)
  if [ -n "$limit" ] && [ "$limit" -gt 0 ] 2>/dev/null; then
    echo "${used}MB / ${limit}MB / ${total}MB"
  else
    echo "${used}MB / $(get_host_available_ram_mb)MB / ${total}MB"
  fi
}
