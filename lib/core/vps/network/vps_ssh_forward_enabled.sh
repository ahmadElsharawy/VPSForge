#!/bin/bash
# Check if public SSH forward is enabled for a VPS (returns 1 only if flag is 'n').
#   vps_ssh_forward_enabled <name>
vps_ssh_forward_enabled() {
  local name="${1:?name}" flag
  flag=$(incus config get "$name" user.vpsforge.ssh_forward 2>/dev/null || true)
  [ "$flag" != "n" ]
}
