#!/bin/bash
# Fetch Cloudflare IP ranges, insert the trusted_proxies block into Caddyfile, and reload Caddy.
#   _cloudflare_enable_realip <caddyfile> <backup>
_cloudflare_enable_realip() {
  local caddyfile="${1:?caddyfile}" backup="${2:?backup}"
  echo "Fetching Cloudflare IP ranges from cloudflare.com..."
  local cf_ipv4 cf_ipv6 all_ips
  cf_ipv4=$(curl -sL --max-time 15 https://www.cloudflare.com/ips-v4)
  cf_ipv6=$(curl -sL --max-time 15 https://www.cloudflare.com/ips-v6)

  if [ -z "$cf_ipv4" ] || [ -z "$cf_ipv6" ]; then
    echo "ERROR: Failed to fetch Cloudflare IPs. Check your internet connection."
    sleep 2
    return 1
  fi

  all_ips=$(echo -e "${cf_ipv4}\n${cf_ipv6}" | grep -v '^$' | tr '\n' ' ')

  if cloudflare_has_foreign_global_block "$caddyfile"; then
    echo "Your Caddyfile already starts with its own global options block { ... }."
    echo "VPSForge will not touch it. Add this line inside its 'servers { }' section yourself:"
    echo "    trusted_proxies static $all_ips"
    pause
    return 0
  fi

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
  return 0
}
