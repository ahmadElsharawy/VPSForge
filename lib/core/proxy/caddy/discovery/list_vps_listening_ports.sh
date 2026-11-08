#!/bin/bash
# Print the TCP ports a VPS is listening on (reachable from the host), one per line.
# Loopback-only listeners and common system ports (22, 25, 53, 111) are skipped.
#   list_vps_listening_ports <vps>
list_vps_listening_ports() {
  local name="${1:?vps}"
  incus exec "$name" -- sh -c '(ss -lntH 2>/dev/null || netstat -lnt 2>/dev/null | tail -n +3)' 2>/dev/null \
    | awk '$4 !~ /^(127\.|\[::1\])/ {print $4}' \
    | sed -E 's/.*:([0-9]+)$/\1/' \
    | grep -E '^[0-9]+$' \
    | sort -un \
    | grep -vxE '22|25|53|111' || true
}
