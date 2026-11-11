#!/bin/bash
# Configure systemd-networkd static networking inside guest containers.
_apply_guest_systemd_networkd() {
  local name="$1" ip="$2" gateway="$3" prefix="$4"

  if incus exec "$name" -- sh -c 'test -d /etc/systemd/network'; then
    incus exec "$name" -- sh -c '
      set -e
      cat > /etc/systemd/network/99-vpsforge.network <<EOF
[Match]
Name=eth0

[Network]
Address='"$ip"'/'"$prefix"'
Gateway='"$gateway"'
DNS=1.1.1.1
DNS=8.8.8.8
EOF
      chmod 644 /etc/systemd/network/99-vpsforge.network
      if command -v systemctl >/dev/null 2>&1; then
        systemctl restart systemd-networkd >/dev/null 2>&1 || true
      fi
    ' || echo "WARNING: systemd-networkd configuration failed in $name."
  fi
}
