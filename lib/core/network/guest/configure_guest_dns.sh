#!/bin/bash
configure_guest_dns() {
  local name="${1:-}"
  [ -n "$name" ] || return 0
  incus exec "$name" -- sh -c '
    set -e
    rm -f /etc/resolv.conf
    cat > /etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
options edns0 trust-ad
EOF
    chmod 644 /etc/resolv.conf
  ' || {
    echo "ERROR: Failed to configure DNS inside $name."
    return 1
  }
}
