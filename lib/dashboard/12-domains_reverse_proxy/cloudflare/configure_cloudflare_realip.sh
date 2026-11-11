#!/bin/bash
# Let Caddy trust Cloudflare's IP ranges so real visitor IPs are logged.
# Only a marked block is added/removed: the rest of the Caddyfile is never overwritten.
configure_cloudflare_realip() {
  ensure_caddy_installed || { pause; return; }
  local caddyfile="$MAIN_CADDYFILE" backup="${MAIN_CADDYFILE}.vpsforge.bak" choice

  while true; do
    clear
    echo "================================================================"
    echo "                  CLOUDFLARE REAL-IP SETUP"
    echo "================================================================"
    if grep -q '^# BEGIN VPSFORGE CLOUDFLARE$' "$caddyfile"; then
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
      1) _cloudflare_enable_realip "$caddyfile" "$backup";;
      2) _cloudflare_disable_realip "$caddyfile" "$backup";;
      *) sleep 1 ;;
    esac
  done
}
