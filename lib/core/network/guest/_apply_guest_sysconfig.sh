#!/bin/bash
# Configure legacy sysconfig network-scripts inside older CentOS/RHEL guests.
_apply_guest_sysconfig() {
  local name="$1" ip="$2" gateway="$3" prefix="$4"

  if incus exec "$name" -- sh -c 'test -d /etc/sysconfig/network-scripts'; then
    incus exec "$name" -- sh -c '
      set -e
      cat > /etc/sysconfig/network-scripts/ifcfg-eth0 <<EOF
DEVICE=eth0
BOOTPROTO=none
ONBOOT=yes
IPADDR='"$ip"'
PREFIX='"$prefix"'
GATEWAY='"$gateway"'
DNS1=1.1.1.1
DNS2=8.8.8.8
EOF
      chmod 644 /etc/sysconfig/network-scripts/ifcfg-eth0
    ' || echo "WARNING: Legacy network scripts configuration failed in $name."
  fi
}
