#!/bin/bash
format_disk_display() {
  local name="$1" used limit total
  used=$(get_vps_disk_usage_gb "$name")
  limit=$(get_vps_disk_limit_gb "$name")
  total=$(get_host_disk_total_gb)
  if [ -n "$limit" ] && [ "$limit" -gt 0 ] 2>/dev/null; then
    echo "${used}GB / ${limit}GB / ${total}GB"
  else
    echo "${used}GB / $(get_host_disk_available_gb)GB / ${total}GB"
  fi
}
