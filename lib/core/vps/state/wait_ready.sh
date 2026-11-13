#!/bin/bash
# Wait until the VPS is RUNNING. Gives up only when it is gone or stopped (it failed to start).
wait_ready() {
  local name="$1" state
  while :; do
    state=$(get_state "$name")
    [ "$state" = "RUNNING" ] && return 0
    { [ -z "$state" ] || [ "$state" = "STOPPED" ]; } && return 1
    sleep 1
  done
}
