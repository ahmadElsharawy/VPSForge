#!/bin/bash
# Poll container until it reaches RUNNING state (up to 30 seconds).
wait_ready() {
  local name="$1" attempt
  for attempt in $(seq 1 30); do
    is_vps_running "$name" && return 0
    sleep 1
  done
  return 1
}
