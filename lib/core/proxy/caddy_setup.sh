#!/bin/bash
# VPSForge v1.0.0 — Caddy reverse proxy setup and installation.

ensure_caddy_installed() {
  command -v caddy >/dev/null 2>&1 && return 0

  echo "Installing Caddy..."
  apt-get update >/dev/null 2>&1
  apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl >/dev/null 2>&1

  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | \
    gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg 2>/dev/null

  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | \
    tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null

  apt-get update >/dev/null 2>&1
  apt-get install -y caddy >/dev/null 2>&1

  if [ ! -d "$CADDY_CONF_DIR" ]; then
    mkdir -p "$CADDY_CONF_DIR"
  fi

  if ! grep -q "import /etc/caddy/vpsforge/*.caddy" "$MAIN_CADDYFILE" 2>/dev/null; then
    echo 'import /etc/caddy/vpsforge/*.caddy' >> "$MAIN_CADDYFILE"
  fi

  # Ensure host firewall permits incoming HTTP (80) and HTTPS (443) for Caddy
  iptables -C INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT 2>/dev/null || \
    iptables -I INPUT 1 -p tcp -m multiport --dports 80,443 -j ACCEPT 2>/dev/null || true
  if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw allow 80/tcp >/dev/null 2>&1 || true
    ufw allow 443/tcp >/dev/null 2>&1 || true
  fi
  save_iptables 2>/dev/null || true

  systemctl enable caddy >/dev/null 2>&1 || true
  systemctl start caddy >/dev/null 2>&1 || true
}
