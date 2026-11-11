#!/bin/bash
# Convert a CIDR prefix length to a dotted-decimal IPv4 netmask.
_cidr_to_netmask() {
  local prefix="${1:-24}"
  local mask=""
  local full_octets=$((prefix / 8))
  local partial_bits=$((prefix % 8))
  local i
  for ((i=0; i<4; i++)); do
    if [ $i -lt $full_octets ]; then
      mask+="${mask:+.}255"
    elif [ $i -eq $full_octets ]; then
      local val=$(( 256 - (1 << (8 - partial_bits)) ))
      mask+="${mask:+.}$val"
    else
      mask+="${mask:+.}0"
    fi
  done
  echo "$mask"
}
