#!/bin/bash
# VPSForge v1.0.0 — VPS state queries.

get_state() {
  local s
  s=$(incus query "/1.0/instances/$1/state" 2>/dev/null |
    python3 -c 'import sys,json; print(json.load(sys.stdin).get("status","").upper())' 2>/dev/null || true)
  if [ -z "$s" ]; then
    s=$(incus list -c ns --format csv 2>/dev/null | awk -F',' -v target="$1" '$1==target {print toupper($2)}')
  fi
  echo "$s"
}

is_vps_running() {
  local s
  s=$(get_state "${1:-}")
  [ "$s" = "RUNNING" ]
}

get_ram() {
  incus config get "$1" limits.memory 2>/dev/null || true
}

wait_ready() {
  local name="$1" i
  for i in $(seq 1 30); do
    is_vps_running "$name" && return 0
    sleep 1
  done
  return 1
}
