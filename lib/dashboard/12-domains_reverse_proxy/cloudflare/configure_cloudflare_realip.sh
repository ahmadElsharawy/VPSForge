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
      1)
        echo "Fetching Cloudflare IP ranges from cloudflare.com..."
        local cf_ipv4 cf_ipv6 all_ips
        cf_ipv4=$(curl -sL --max-time 15 https://www.cloudflare.com/ips-v4)
        cf_ipv6=$(curl -sL --max-time 15 https://www.cloudflare.com/ips-v6)

        if [ -z "$cf_ipv4" ] || [ -z "$cf_ipv6" ]; then
          echo "ERROR: Failed to fetch Cloudflare IPs. Check your internet connection."
          sleep 2
          continue
        fi

        if cloudflare_has_foreign_global_block "$caddyfile"; then
          echo "Your Caddyfile already starts with its own global options block { ... }."
          echo "VPSForge will not touch it. Add this line inside its 'servers { }' section yourself:"
          echo "    trusted_proxies static $(echo -e "${cf_ipv4}\n${cf_ipv6}" | grep -v '^$' | tr '\n' ' ')"
          pause
          continue
        fi

        all_ips=$(echo -e "${cf_ipv4}\n${cf_ipv6}" | grep -v '^$' | tr '\n' ' ')
        cp -f "$caddyfile" "$backup"
        cloudflare_remove_block "$caddyfile"
        {
          echo "# BEGIN VPSFORGE CLOUDFLARE"
          echo "{"
          echo "    servers {"
          echo "        trusted_proxies static $all_ips"
          echo "    }"
          echo "}"
          echo "# END VPSFORGE CLOUDFLARE"
          cat "$caddyfile"
        } > "${caddyfile}.new" && mv -f "${caddyfile}.new" "$caddyfile"

        if caddy_apply_or_rollback "$caddyfile" "$backup"; then
          echo "SUCCESS: Cloudflare Real-IP is now ENABLED!"
        fi
        pause
        ;;
      2)
        cp -f "$caddyfile" "$backup"
        cloudflare_remove_block "$caddyfile"
        if caddy_apply_or_rollback "$caddyfile" "$backup"; then
          echo "SUCCESS: Cloudflare Real-IP is now DISABLED."
        fi
        pause
        ;;
      *) sleep 1 ;;
    esac
  done
}
