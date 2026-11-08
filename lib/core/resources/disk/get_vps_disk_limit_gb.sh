#!/bin/bash
get_vps_disk_limit_gb() {
  local raw
  raw=$(incus config device get "$1" root size 2>/dev/null || true)
  [ -n "$raw" ] || return 0
  echo "$raw" | awk '
    /GiB$/ {gsub(/GiB/,""); printf "%d",$1; exit}
    /GB$/  {gsub(/GB/,"");  printf "%d",$1; exit}
    /MiB$/ {gsub(/MiB/,""); printf "%d",$1/1024; exit}'
}
