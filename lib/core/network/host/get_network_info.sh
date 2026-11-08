#!/bin/bash
# Returns 1 (instead of killing the whole program) if the bridge has no IPv4
# while the program is already running; startup treats a failure as fatal.
get_network_info() {
  local cidr
  cidr=$(incus network get incusbr0 ipv4.address 2>/dev/null || true)
  if [ -z "$cidr" ] || [ "$cidr" = "none" ]; then
    echo "incusbr0 has no IPv4." >&2
    return 1
  fi
  INCUS_CIDR="$cidr"
  INCUS_GATEWAY="${INCUS_CIDR%/*}"
  INCUS_NETMASK="${INCUS_CIDR#*/}"
  local A B C D
  IFS='.' read -r A B C D <<< "$INCUS_GATEWAY"
  NETWORK_PREFIX="$A.$B.$C"
}
