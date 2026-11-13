#!/bin/bash
# Wait until the SSH daemon listens on port 22 in a guest VPS. Gives up only if the VPS is no longer RUNNING.
_wait_ssh_listening() {
  local name="$1"
  until incus exec "$name" -- sh -c '(ss -lnt 2>/dev/null || netstat -lnt 2>/dev/null) | grep -qE "[:.]22([[:space:]]|$)"'; do
    is_vps_running "$name" || return 1
    sleep 1
  done
  return 0
}
