#!/bin/bash
guest_network_config_ok() {
  local name="$1" ip="${2:-}" gateway="${3:-}" prefix="${4:-24}"
  local route_ok=0 resolv_ok=0 addr_ok=0

  if [ -n "$gateway" ]; then
    incus exec "$name" -- sh -lc 'ip -4 route show default | grep -Fq -- "default via '"$gateway"' dev eth0"' >/dev/null 2>&1
  else
    incus exec "$name" -- sh -lc 'ip -4 route show default | grep -q "^default "' >/dev/null 2>&1
  fi
  route_ok=$?

  incus exec "$name" -- sh -lc 'grep -Fqx "nameserver 1.1.1.1" /etc/resolv.conf && grep -Fqx "nameserver 8.8.8.8" /etc/resolv.conf' >/dev/null 2>&1
  resolv_ok=$?

  if [ -n "$ip" ]; then
    incus exec "$name" -- sh -lc 'ip -4 addr show dev eth0 | grep -Fq -- "'"$ip"'/'"$prefix"'"' >/dev/null 2>&1
    addr_ok=$?
  fi

  [ "$route_ok" -eq 0 ] && [ "$resolv_ok" -eq 0 ] && [ "$addr_ok" -eq 0 ]
}
