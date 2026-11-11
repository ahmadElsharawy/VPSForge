#!/bin/bash
# Remove Cloudflare Real-IP block from Caddyfile and reload Caddy.
#   _cloudflare_disable_realip <caddyfile> <backup>
_cloudflare_disable_realip() {
  local caddyfile="${1:?caddyfile}" backup="${2:?backup}"
  cp -f "$caddyfile" "$backup"
  cloudflare_remove_block "$caddyfile"
  if caddy_apply_or_rollback "$caddyfile" "$backup"; then
    echo "SUCCESS: Cloudflare Real-IP is now DISABLED."
  fi
  pause
  return 0
}
