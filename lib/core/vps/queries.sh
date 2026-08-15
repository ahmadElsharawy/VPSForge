#!/bin/bash
# VPSForge v1.0.0 — VPS state queries.

get_state() {
  incus query "/1.0/instances/$1/state" 2>/dev/null |
    python3 -c 'import sys,json; print(json.load(sys.stdin).get("status",""))' 2>/dev/null || true
}

get_ram() {
  incus config get "$1" limits.memory 2>/dev/null || true
}

wait_ready() {
  local name="$1" i
  for i in $(seq 1 30); do
    [ "$(get_state "$name")" = "Running" ] || [ "$(get_state "$name")" = "RUNNING" ] && return 0
    sleep 1
  done
  return 1
}
