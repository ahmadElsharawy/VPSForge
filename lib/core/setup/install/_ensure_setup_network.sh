#!/bin/bash
# Configure IP forwarding, inter-VPS isolation, and Caddy firewall ports.
_ensure_setup_network() {
  sysctl -w net.ipv4.ip_forward=1 >/dev/null
  echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-incus-forwarding.conf

  setup_inter_vps_isolation

  # Ensure host firewall permits incoming HTTP (80) and HTTPS (443) for Caddy Reverse Proxy
  iptables -C INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT 2>/dev/null || \
    iptables -I INPUT 1 -p tcp -m multiport --dports 80,443 -j ACCEPT 2>/dev/null || true
  if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw allow 80/tcp >/dev/null 2>&1 || true
    ufw allow 443/tcp >/dev/null 2>&1 || true
  fi
  save_iptables 2>/dev/null || true
}
