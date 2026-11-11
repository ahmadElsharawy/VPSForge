#!/bin/bash
# Returns configured RAM limit in MB for a VPS container, or empty if unlimited.
get_vps_ram_limit_mb() {
  local vps_name="$1" raw
  raw=$(incus config get "$vps_name" limits.memory 2>/dev/null || true)
  [ -n "$raw" ] || return 0
  ram_mb "$raw"
}
