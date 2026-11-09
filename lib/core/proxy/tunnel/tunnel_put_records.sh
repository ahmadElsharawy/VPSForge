#!/bin/bash
# Save the tunnel list of a VPS (one record per line on stdin; no lines = no tunnels).
#   tunnel_put_records <vps>
tunnel_put_records() {
  local vps="${1:?vps}" line joined=""
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    joined+="${line};"
  done
  if [ -n "$joined" ]; then
    incus config set "$vps" user.vpsforge.tunnels "${joined%;}"
  else
    incus config unset "$vps" user.vpsforge.tunnels 2>/dev/null || true
  fi
}
