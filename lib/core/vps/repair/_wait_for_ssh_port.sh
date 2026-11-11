#!/bin/bash
# Wait up to 15 seconds for SSH port on container IP to accept TCP connections.
_wait_for_ssh_port() {
  local ip="$1" attempt
  for attempt in $(seq 1 15); do
    timeout 2 bash -c "</dev/tcp/$ip/22" >/dev/null 2>&1 && return 0
    sleep 1
  done
  return 1
}
