#!/bin/bash
wait_guest_eth0() {
  local name="$1" i
  for i in $(seq 1 30); do
    incus exec "$name" -- ip link show dev eth0 >/dev/null 2>&1 && return 0
    sleep 1
  done
  return 1
}
