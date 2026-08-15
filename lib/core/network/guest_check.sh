#!/bin/bash
# VPSForge v1.0.0 — Guest network verification and diagnostics.

diagnose_guest_network() {
  local name="$1" ip="${2:-}"

  echo "Guest network diagnostics for $name:"
  incus config show "$name" --expanded 2>/dev/null | awk '
    BEGIN { in_eth0=0 }
    /^[[:space:]]{2}eth0:/ { in_eth0=1; print "  eth0:"; next }
    /^[[:space:]]{2}[a-zA-Z0-9_.-]+:/ {
      if (in_eth0) in_eth0=0
    }
    in_eth0 && /^[[:space:]]{4}/ {
      print "  " $0
    }
  '

  incus exec "$name" -- sh -lc '
    echo "  inside-container routes:"
    ip -4 route || true
    echo "  inside-container addresses:"
    ip -4 addr show dev eth0 2>/dev/null || true
    echo "  inside-container resolv.conf:"
    if [ -r /etc/resolv.conf ]; then cat /etc/resolv.conf
    else echo "    missing /etc/resolv.conf"
    fi
  '

  [ -n "$ip" ] && echo "  expected IPv4: $ip"
}

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

configure_vps_network_device() {
  local name="$1"
  ensure_device_override "$name" eth0 || return 1
  incus config device unset "$name" eth0 ipv4.address >/dev/null 2>&1 || true
  incus config device unset "$name" eth0 ipv4.gateway >/dev/null 2>&1 || true
  incus config device unset "$name" eth0 hwaddr >/dev/null 2>&1 || true
  incus config unset "$name" volatile.eth0.hwaddr >/dev/null 2>&1 || true
  incus config unset "$name" volatile.eth0.host_name >/dev/null 2>&1 || true
  incus config device set "$name" eth0 name eth0 || true
  incus config device set "$name" eth0 network incusbr0 || true
}
