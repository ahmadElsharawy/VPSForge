#!/bin/bash
# Configure NetworkManager static keyfile inside RHEL/Fedora guest containers.
_apply_guest_networkmanager() {
  local name="$1" ip="$2" gateway="$3" prefix="$4"

  if incus exec "$name" -- sh -c 'test -d /etc/NetworkManager/system-connections'; then
    incus exec "$name" -- sh -c '
      set -e
      # Stop NetworkManager making its own DHCP "Wired connection 1" for eth0; that auto
      # connection fights our static keyfile and, on RHEL/Rocky/Alma 10, wins and leaves
      # eth0 down with no route. This file also prevents it coming back on reboot.
      mkdir -p /etc/NetworkManager/conf.d
      printf "[main]\nno-auto-default=*\n" > /etc/NetworkManager/conf.d/00-vpsforge-no-auto-default.conf

      cat > /etc/NetworkManager/system-connections/vpsforge-eth0.nmconnection <<EOF
[connection]
id=vpsforge-eth0
uuid=73a38ff1-789a-4c22-b5cc-485db1f94c48
type=ethernet
interface-name=eth0
autoconnect=true
autoconnect-priority=999

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
        # Right after boot NetworkManager may still be starting, so its commands would no-op
        # and it would later grab eth0 itself. Wait for it to be ready first.
        i=0
        while [ "$i" -lt 120 ]; do
          state=$(nmcli -t -f STATE general 2>/dev/null || true)
          [ -n "$state" ] && [ "$state" != "unknown" ] && [ "$state" != "asleep" ] && break
          sleep 1; i=$((i + 1))
        done
        nmcli general reload >/dev/null 2>&1 || true
        # Drop any other connection bound to eth0 (by UUID, so names with spaces are handled).
        for u in $(nmcli -t -f UUID,DEVICE connection show 2>/dev/null | grep ":eth0$" | cut -d: -f1); do
          [ "$u" = "73a38ff1-789a-4c22-b5cc-485db1f94c48" ] || nmcli connection delete "$u" >/dev/null 2>&1 || true
        done
        nmcli connection reload >/dev/null 2>&1 || true
        nmcli connection up vpsforge-eth0 >/dev/null 2>&1 || true
      fi
    ' || echo "WARNING: NetworkManager keyfile configuration failed in $name."
  fi
}
