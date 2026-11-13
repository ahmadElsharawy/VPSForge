#!/bin/bash
# Wait until the SSH port on the container IP accepts TCP connections. Gives up only if the VPS is no longer RUNNING.
#   _wait_for_ssh_port <ip> <vps_name>
_wait_for_ssh_port() {
  local ip="$1" name="${2:?vps}"
  until timeout 2 bash -c "</dev/tcp/$ip/22" >/dev/null 2>&1; do
    is_vps_running "$name" || return 1
    sleep 1
  done
  return 0
}
