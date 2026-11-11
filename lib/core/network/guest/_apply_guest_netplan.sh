#!/bin/bash
# Configure Netplan static networking inside Ubuntu/Debian guest containers.
_apply_guest_netplan() {
  local name="$1" ip="$2" gateway="$3" prefix="$4"

  # Disable cloud-init network configuration to prevent netplan overwrites on boot
  if incus exec "$name" -- sh -c 'test -d /etc/cloud/cloud.cfg.d'; then
    incus exec "$name" -- sh -c '
      cat > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg <<EOF
network: {config: disabled}
EOF
    ' >/dev/null 2>&1 || true
  fi

  if incus exec "$name" -- sh -c 'command -v netplan >/dev/null 2>&1'; then
    incus exec "$name" -- sh -c '
      set -e
      mkdir -p /etc/netplan
      for f in /etc/netplan/*.yaml /etc/netplan/*.yml; do
        [ -f "$f" ] && [ "$f" != "/etc/netplan/99-vpsforge.yaml" ] && mv "$f" "${f}.disabled" 2>/dev/null || true
      done
      cat > /etc/netplan/99-vpsforge.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
      mtu: 1420
      addresses:
        - "'"$ip"'/'"$prefix"'"
      routes:
        - to: default
          via: "'"$gateway"'"
      nameservers:
        addresses:
          - 1.1.1.1
          - 8.8.8.8
EOF
      chmod 600 /etc/netplan/99-vpsforge.yaml
      if command -v systemctl >/dev/null 2>&1; then
        systemctl enable systemd-networkd >/dev/null 2>&1 || true
        systemctl start systemd-networkd >/dev/null 2>&1 || true
      fi
      netplan generate >/dev/null 2>&1 || true
      netplan apply >/dev/null 2>&1 || true
    ' || echo "WARNING: Netplan configuration generation failed in $name."
  fi
}
