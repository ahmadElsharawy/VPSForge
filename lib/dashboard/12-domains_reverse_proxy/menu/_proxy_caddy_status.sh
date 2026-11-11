#!/bin/bash
# Return current Caddy installation and service status string.
_proxy_caddy_status() {
  if command -v caddy >/dev/null 2>&1 && systemctl is-active --quiet caddy; then
    echo "running"
  elif command -v caddy >/dev/null 2>&1; then
    echo "installed but NOT running"
  else
    echo "not installed yet (installed automatically when you add a domain)"
  fi
}
