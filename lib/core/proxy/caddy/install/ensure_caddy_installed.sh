#!/bin/bash
# Make sure Caddy is installed AND wired to VPSForge's config folder.
# (Previously the wiring was skipped when Caddy was already installed.)
ensure_caddy_installed() {
  if ! command -v caddy >/dev/null 2>&1; then
    _install_caddy_package || return 1
  fi

  mkdir -p "$CADDY_CONF_DIR"
  [ -f "$MAIN_CADDYFILE" ] || touch "$MAIN_CADDYFILE"

  # Wire the config folder into the main Caddyfile (also when Caddy was already installed).
  if ! grep -qF 'import /etc/caddy/vpsforge/*.caddy' "$MAIN_CADDYFILE" 2>/dev/null; then
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
  return 0
}
