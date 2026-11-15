#!/bin/bash
# Wait until the VPS is RUNNING. Gives up when it is gone, stopped (it failed to start), in ERROR or frozen.
wait_ready() {
  local name="$1" state
  while :; do
    state=$(get_state "$name")
    [ "$state" = "RUNNING" ] && return 0
    case "$state" in ""|STOPPED|ERROR|FROZEN) return 1;; esac   # gone, failed to start, broken or paused: never RUNNING by itself
    sleep 1
  done
}
