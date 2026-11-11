#!/bin/bash
# Read bridge network IPv4 settings (CIDR, gateway, netmask, prefix) from incusbr0.
# Returns 1 if the bridge has no IPv4 configured.
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
  local octet_a octet_b octet_c octet_d
  IFS='.' read -r octet_a octet_b octet_c octet_d <<< "$INCUS_GATEWAY"
  NETWORK_PREFIX="$octet_a.$octet_b.$octet_c"
}
