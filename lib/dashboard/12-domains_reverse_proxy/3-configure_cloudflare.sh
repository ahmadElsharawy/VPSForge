#!/bin/bash
# VPSForge v1.0.0 — Cloudflare Real-IP configuration.

configure_cloudflare_realip() {
  ensure_caddy_installed
  local caddyfile="/etc/caddy/Caddyfile"
  
  while true; do
    clear
    echo "================================================================"
    echo "                  CLOUDFLARE REAL-IP SETUP"
    echo "================================================================"
    if grep -q "trusted_proxies" "$caddyfile"; then
      echo "Status: ENABLED (Caddy will trust Cloudflare IPs)"
    else
      echo "Status: DISABLED"
    fi
    echo "================================================================"
    echo "0) Back"
    echo "1) Enable / Update Cloudflare IPs"
    echo "2) Disable Cloudflare Real-IP"
    echo "================================================================"
    read -r -p "Choice [0=Back, Enter=1]: " choice
    choice="${choice:-1}"
    case "$choice" in
      0) break ;;
      1)
        echo "Fetching Cloudflare IP ranges from cloudflare.com..."
        local cf_ipv4 cf_ipv6
        cf_ipv4=$(curl -sL https://www.cloudflare.com/ips-v4)
        cf_ipv6=$(curl -sL https://www.cloudflare.com/ips-v6)

        if [ -z "$cf_ipv4" ] || [ -z "$cf_ipv6" ]; then
          echo "ERROR: Failed to fetch Cloudflare IPs. Check your internet connection."
          sleep 2
          continue
        fi

        local all_ips
        all_ips=$(echo -e "${cf_ipv4}\n${cf_ipv6}" | grep -v "^$" | tr '\n' ' ')
        
        cat > "$caddyfile" <<EOF
{
    servers {
        trusted_proxies static $all_ips
    }
}
import /etc/caddy/vpsforge/*.caddy
EOF

        if caddy validate --config "$caddyfile" >/dev/null 2>&1; then
          systemctl reload-or-restart caddy >/dev/null 2>&1 || true
          echo "SUCCESS: Cloudflare Real-IP is now ENABLED!"
        else
          echo "ERROR: Validation failed. Reverting..."
          echo "import /etc/caddy/vpsforge/*.caddy" > "$caddyfile"
          systemctl reload-or-restart caddy >/dev/null 2>&1 || true
        fi
        pause
        ;;
      2)
        echo "import /etc/caddy/vpsforge/*.caddy" > "$caddyfile"
        systemctl reload-or-restart caddy >/dev/null 2>&1 || true
        echo "SUCCESS: Cloudflare Real-IP is now DISABLED."
        pause
        ;;
      *) sleep 1 ;;
    esac
  done
}
