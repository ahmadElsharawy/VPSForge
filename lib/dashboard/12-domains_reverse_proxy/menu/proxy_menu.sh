#!/bin/bash
# Main menu 12: Domains & Reverse Proxy. Three simple choices.
proxy_menu() {
  local choice count caddy_state
  while true; do
    count=$(list_proxy_routes 2>/dev/null | wc -l)
    if command -v caddy >/dev/null 2>&1 && systemctl is-active --quiet caddy; then
      caddy_state="running"
    elif command -v caddy >/dev/null 2>&1; then
      caddy_state="installed but NOT running"
    else
      caddy_state="not installed yet (installed automatically when you add a domain)"
    fi

    clear
    echo "================================================================"
    echo "                DOMAINS & REVERSE PROXY (HTTPS)"
    echo "================================================================"
    echo "Caddy: $caddy_state   |   Domains: $count"
    echo "----------------------------------------------------------------"
    echo "1) Add a domain       (domain -> app inside one of your VPSs)"
    echo "2) My domains        (list, test, remove)"
    echo "3) Cloudflare real visitor IP   (optional)"
    echo "0) Back"
    echo "================================================================"
    read -r -p "Choice [0=Back, Enter=1]: " choice
    choice="${choice:-1}"
    case "$choice" in
      0) break ;;
      1) proxy_add_site_wizard ;;
      2) proxy_my_sites_menu ;;
      3) configure_cloudflare_realip ;;
      *) echo "Invalid option."; sleep 1 ;;
    esac
  done
}
