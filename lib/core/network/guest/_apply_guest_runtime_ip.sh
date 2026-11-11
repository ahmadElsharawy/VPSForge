#!/bin/bash
# Apply immediate runtime IP address and default route via ip command in guest.
_apply_guest_runtime_ip() {
  local name="$1" ip="$2" gateway="$3" prefix="$4"

  incus exec "$name" -- sh -c '
    set -e
    ip link set eth0 mtu 1420 2>/dev/null || true
    ip link set eth0 up
    ip -4 addr flush dev eth0 scope global || true
    ip -4 addr add '"$ip"'/'"$prefix"' dev eth0
    ip route replace default via '"$gateway"' dev eth0
    ip -4 addr show dev eth0 | grep -Fq -- "'"$ip"'/'"$prefix"'"
    ip -4 route show default | grep -Fq -- "default via '"$gateway"' dev eth0"
  ' || {
    echo "ERROR: ip-based guest network setup failed inside $name."
    return 1
  }
}
