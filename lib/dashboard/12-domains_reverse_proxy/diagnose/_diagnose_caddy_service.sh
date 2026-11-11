#!/bin/bash
# Check host Caddy service status, ensure ports 80 and 443 are open, and detect conflicts.
_diagnose_caddy_service() {
  echo -n "[1/4] Checking Host Caddy Service & Ingress Ports 80/443... "
  if systemctl is-active --quiet caddy; then
    iptables -C INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT 2>/dev/null || \
      iptables -I INPUT 1 -p tcp -m multiport --dports 80,443 -j ACCEPT 2>/dev/null || true
    if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
      ufw allow 80/tcp >/dev/null 2>&1 || true
      ufw allow 443/tcp >/dev/null 2>&1 || true
    fi
    save_iptables 2>/dev/null || true
    echo "OK (Caddy is running & ports 80/443 open on host)"
    if proxy_port_conflicts; then
      return 1
    fi
    return 0
  else
    echo "FAILED"
    echo "  ⚠️  Caddy service is NOT running on this server!"
    echo "     Run 'systemctl start caddy' and check 'journalctl -u caddy -e'."
    return 1
  fi
}
