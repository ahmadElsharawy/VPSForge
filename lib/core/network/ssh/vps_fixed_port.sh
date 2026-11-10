#!/bin/bash
# SSH port of a VPS on this server: 9000 + its number (vps1 -> 9001 ... vps254 -> 9254).
# A name instead of a number gets a stable port from a hash, in 9300-9999 so it can never
# fall on a numbered VPS's port.
#   vps_fixed_port <number|name>
vps_fixed_port() {
  local num="$1"
  if [[ "$num" =~ ^[0-9]+$ ]]; then
    echo $((SSH_PORT_BASE + num))
  else
    local hash
    hash=$(echo -n "$num" | cksum | awk '{print $1}')
    echo $((SSH_PORT_BASE + 300 + (hash % 700)))
  fi
}
