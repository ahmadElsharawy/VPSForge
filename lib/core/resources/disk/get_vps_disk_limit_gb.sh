#!/bin/bash
# Returns root disk limit in GB for a VPS container.
get_vps_disk_limit_gb() {
  local vps_name="$1" raw
  raw=$(incus config device get "$vps_name" root size 2>/dev/null || true)
  [ -n "$raw" ] || return 0
  echo "$raw" | awk '
    /GiB$/ {gsub(/GiB/,""); printf "%d",$1; exit}
    /GB$/  {gsub(/GB/,"");  printf "%d",$1; exit}
    /MiB$/ {gsub(/MiB/,""); printf "%d",$1/1024; exit}'
}
