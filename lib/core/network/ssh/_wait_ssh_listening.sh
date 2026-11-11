#!/bin/bash
# Wait up to 30 seconds for the SSH daemon to begin listening on port 22 in a guest VPS.
_wait_ssh_listening() {
  local name="$1" i
  for i in $(seq 1 30); do
    incus exec "$name" -- sh -c '(ss -lnt 2>/dev/null || netstat -lnt 2>/dev/null) | grep -qE "[:.]22([[:space:]]|$)"' && return 0
    sleep 1
  done
  return 1
}
