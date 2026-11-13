#!/bin/bash
# Wait until the eth0 network interface appears inside a guest VPS. Gives up only if the VPS is no longer RUNNING.
wait_guest_eth0() {
  local name="$1"
  until incus exec "$name" -- ip link show dev eth0 >/dev/null 2>&1; do
    is_vps_running "$name" || return 1
    sleep 1
  done
  return 0
}
