#!/bin/bash
# Print the tunnels saved on a VPS, one per line:  tunnel_port|my_pc_port|public_port|domain|state
# They live in the VPS's own Incus metadata, so they are removed together with the VPS.
#   tunnel_get_records <vps>
tunnel_get_records() {
  local vps="${1:?vps}" raw
  raw=$(incus config get "$vps" user.vpsforge.tunnels 2>/dev/null || true)
  [ -n "$raw" ] || return 0
  tr ';' '\n' <<< "$raw" | grep -v '^$' || true
}
