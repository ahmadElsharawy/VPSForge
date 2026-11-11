#!/bin/bash
# Configure NetworkManager static keyfile inside RHEL/Fedora guest containers.
_apply_guest_networkmanager() {
  local name="$1" ip="$2" gateway="$3" prefix="$4"

  if incus exec "$name" -- sh -c 'test -d /etc/NetworkManager/system-connections'; then
    incus exec "$name" -- sh -c '
      set -e
      cat > /etc/NetworkManager/system-connections/vpsforge-eth0.nmconnection <<EOF
[connection]
id=vpsforge-eth0
uuid=73a38ff1-789a-4c22-b5cc-485db1f94c48
type=ethernet
interface-name=eth0

[ethernet]
cloned-mac-address=preserve

[ipv4]
method=manual
address1='"$ip"'/'"$prefix"','"$gateway"'
dns=1.1.1.1;8.8.8.8;

[ipv6]
method=ignore
EOF
      chmod 600 /etc/NetworkManager/system-connections/vpsforge-eth0.nmconnection
      if command -v nmcli >/dev/null 2>&1; then
        nmcli connection reload >/dev/null 2>&1 || true
        nmcli connection up vpsforge-eth0 >/dev/null 2>&1 || true
      fi
    ' || echo "WARNING: NetworkManager keyfile configuration failed in $name."
  fi
}
