#!/bin/bash
vps_fixed_port() {
  local num="$1"
  if [[ "$num" =~ ^[0-9]+$ ]]; then
    echo $((SSH_PORT_BASE + num))
  else
    local hash
    hash=$(echo -n "$num" | cksum | awk '{print $1}')
    echo $((SSH_PORT_BASE + (hash % 900) + 1))
  fi
}
