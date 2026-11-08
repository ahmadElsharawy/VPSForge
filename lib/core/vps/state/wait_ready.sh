#!/bin/bash
wait_ready() {
  local name="$1" i
  for i in $(seq 1 30); do
    is_vps_running "$name" && return 0
    sleep 1
  done
  return 1
}
