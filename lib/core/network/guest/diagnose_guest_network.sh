#!/bin/bash
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
