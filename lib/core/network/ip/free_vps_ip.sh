#!/bin/bash
# Print an address in the VPS network that no VPS uses (saved or live), searching from the top
# of the range (.250 down) so it never takes the next "normal" address. One `incus list` call.
#   free_vps_ip
free_vps_ip() {
  [ -n "${NETWORK_PREFIX:-}" ] || get_network_info 2>/dev/null || true
  local used_ips octet
  used_ips=$(vps_inventory 2>/dev/null | awk -F'|' '{ print $2 }')
  for octet in $(seq 250 -1 "$((IP_START + 1))"); do
    grep -qxF "${NETWORK_PREFIX}.$octet" <<< "$used_ips" || { echo "${NETWORK_PREFIX}.$octet"; return 0; }
  done
  return 1
}
