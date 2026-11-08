#!/bin/bash
get_vps_ram_limit_mb() {
  local raw
  raw=$(incus config get "$1" limits.memory 2>/dev/null || true)
  [ -n "$raw" ] || return 0
  ram_mb "$raw"
}
