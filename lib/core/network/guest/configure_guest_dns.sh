#!/bin/bash
# Give a VPS fixed DNS servers (1.1.1.1 and 8.8.8.8). Some systems (for example Alpine with dhcpcd)
# rewrite /etc/resolv.conf themselves, so those are told to leave it alone first.
configure_guest_dns() {
  local name="${1:-}"
  [ -n "$name" ] || return 0
  incus exec "$name" -- sh -c '
    set -e
    # dhcpcd would overwrite resolv.conf with the DHCP/RA answers: stop it from touching the file
    if [ -f /etc/dhcpcd.conf ] && ! grep -q "nohook resolv.conf" /etc/dhcpcd.conf; then
      echo "nohook resolv.conf" >> /etc/dhcpcd.conf
      if command -v rc-service >/dev/null 2>&1; then rc-service dhcpcd restart >/dev/null 2>&1 || true; fi
      sleep 1
    fi
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
